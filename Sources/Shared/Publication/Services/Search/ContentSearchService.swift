//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Implementation of `SearchService` using the Content API (`ContentService`).
///
/// It supports cross-element matching within the same resource via a
/// *tail-carry* mechanism: the last *T* characters of the preceding element are
/// prepended to the current element's text, so queries that span a paragraph or
/// heading boundary are found correctly.
///
/// Cross-resource matching is intentionally not supported (the tail is flushed
/// at every resource boundary).
///
/// **Regex limitation:** for variable-length or greedy patterns the danger-zone
/// heuristic (last 256 chars) is an approximation. A greedy pattern that starts
/// before the danger zone but could extend further into the next element may be
/// emitted prematurely, with a shorter-than-optimal match. Plain-text queries
/// are not affected by this limitation.
///
/// This service requires the publication to have a configured `ContentService`.
public class ContentSearchService: SearchService, Loggable {
    /// - Parameters:
    ///   - snippetLength: Maximum length of the `before` and `after` text
    ///     snippets in the returned locators.
    ///   - searchAlgorithm: Implements the actual search algorithm in the
    ///     sanitized text.
    public static func makeFactory(
        snippetLength: Int = 200,
        searchAlgorithm: StringSearchAlgorithm = BasicStringSearchAlgorithm()
    ) -> (PublicationServiceContext) -> ContentSearchService? {
        { context in
            ContentSearchService(
                publication: context.publication,
                language: context.manifest.metadata.language,
                snippetLength: snippetLength,
                searchAlgorithm: searchAlgorithm
            )
        }
    }

    public let options: SearchOptions

    private let publication: Weak<Publication>
    private let language: Language?
    private let snippetLength: Int
    private let searchAlgorithm: StringSearchAlgorithm

    public init(
        publication: Weak<Publication>,
        language: Language?,
        snippetLength: Int,
        searchAlgorithm: StringSearchAlgorithm
    ) {
        self.publication = publication
        self.language = language
        self.snippetLength = snippetLength
        self.searchAlgorithm = searchAlgorithm

        var options = searchAlgorithm.options
        options.language = language ?? Language.current
        self.options = options
    }

    public func search(query: String, options: SearchOptions?) async -> SearchResult<any SearchIterator> {
        guard let content = publication()?.content() else {
            log(.error, "ContentSearchService requires a ContentService but none is registered for this publication.")
            return .failure(.publicationNotSearchable)
        }
        return .success(Iterator(
            contentIterator: content.iterator(),
            language: language,
            snippetLength: snippetLength,
            searchAlgorithm: searchAlgorithm,
            query: query,
            options: options
        ))
    }
}

/// Maps a span of characters in a search string to a content segment's locator.
private struct SearchUnit {
    let locator: Locator
    let range: Range<Int>
    let isSeparator: Bool
}

private final class Iterator: SearchIterator, Loggable, @unchecked Sendable {
    private let lock = NSLock()

    private var _resultCount: Int = 0

    var resultCount: Int? {
        lock.lock()
        defer { lock.unlock() }
        return _resultCount
    }

    private let contentIterator: ContentIterator
    private let snippetLength: Int
    private let searchAlgorithm: StringSearchAlgorithm
    private let query: String
    private let options: SearchOptions
    private let currentLanguage: Language?

    // Tail-carry state
    private var tail: String = ""
    private var tailUnits: [SearchUnit] = []
    private let tailCapacity: Int

    /// Extra characters stored beyond `snippetLength` in the context buffers.
    /// Ensures `extractSnippetBefore/After` — which may overshoot `snippetLength`
    /// by up to one word — never reaches a hard-truncated buffer edge.
    private let snippetWordOvershootMargin = 100

    // Per-resource batching state
    private var currentHREF: AnyURL?
    private var pendingLocators: [Locator] = []

    /// Snippet context: last snippetLength chars from earlier elements in the
    /// current resource, ending where the current tail begins. Used to extend
    /// before-snippets beyond the tail window.
    private var snippetContextBuffer: String = ""

    /// Lookahead queue for after-snippet context: elements read ahead from the
    /// ContentIterator but not yet processed for matching.
    private var lookaheadQueue: [ContentElement] = []

    fileprivate init(
        contentIterator: ContentIterator,
        language: Language?,
        snippetLength: Int,
        searchAlgorithm: StringSearchAlgorithm,
        query: String,
        options: SearchOptions?
    ) {
        self.contentIterator = contentIterator
        self.snippetLength = snippetLength
        self.searchAlgorithm = searchAlgorithm
        self.query = query
        self.options = options ?? SearchOptions()
        currentLanguage = self.options.language ?? language
        tailCapacity = (self.options.regularExpression ?? false)
            ? 256
            : max(0, query.count - 1)
    }

    /// Thread-safe increment of result count
    private func incrementResultCount(by count: Int) {
        lock.lock()
        defer { lock.unlock() }
        _resultCount += count
    }

    // MARK: - next()

    func next() async -> SearchResult<LocatorCollection?> {
        while let element = await nextElement() {
            guard !Task.isCancelled else {
                return emitBatch()
            }

            guard
                let textElement = element as? TextContentElement,
                !textElement.segments.isEmpty
            else {
                continue
            }

            if textElement.locator.href != currentHREF {
                if let batch = await handleResourceBoundary(newElement: textElement) {
                    return batch
                }
                // Fall-through: no pending batch — process newElement on the shared path.
            }

            // Shared path: normal elements AND boundary fall-through.
            await fillLookahead(currentHREF: currentHREF)
            let afterCtx = afterContextText(currentHREF: currentHREF)
            await pendingLocators.append(contentsOf: processElement(textElement, afterContext: afterCtx))
        }

        // Content exhausted — flush any remaining deferred matches.
        await pendingLocators.append(contentsOf: flushTail())
        return emitBatch()
    }

    /// Handles a resource-boundary transition when `newElement` belongs to a
    /// different resource than `currentHREF`.
    ///
    /// If a batch of pending locators has accumulated, emits it while starting
    /// to process `newElement` for the next batch.
    ///
    /// - Returns `.success` with the ready batch, or `nil` to signal
    ///   fall-through to the shared element-processing path (no batch was ready
    ///   to emit).
    private func handleResourceBoundary(newElement: TextContentElement) async -> SearchResult<LocatorCollection?>? {
        let tailLocators = await flushTail()
        pendingLocators.append(contentsOf: tailLocators)
        snippetContextBuffer = ""
        currentHREF = newElement.locator.href

        guard !pendingLocators.isEmpty else {
            return nil
        }

        let batch = pendingLocators
        pendingLocators = []
        await fillLookahead(currentHREF: currentHREF)
        let afterCtx = afterContextText(currentHREF: currentHREF)
        await pendingLocators.append(contentsOf: processElement(newElement, afterContext: afterCtx))
        incrementResultCount(by: batch.count)
        return .success(LocatorCollection(locators: batch))
    }

    /// Returns whatever is in `pendingLocators` as a batch result.
    private func emitBatch() -> SearchResult<LocatorCollection?> {
        guard !pendingLocators.isEmpty else { return .success(nil) }
        let batch = pendingLocators
        pendingLocators = []
        incrementResultCount(by: batch.count)
        return .success(LocatorCollection(locators: batch))
    }

    /// Drains from `lookaheadQueue` first, then falls back to the ContentIterator.
    private func nextElement() async -> ContentElement? {
        if !lookaheadQueue.isEmpty {
            return lookaheadQueue.removeFirst()
        }
        return await rawNextElement()
    }

    /// Advances the ContentIterator directly, returning `nil` on normal exhaustion
    /// or on an iterator error (which is logged but not propagated).
    private func rawNextElement() async -> ContentElement? {
        do {
            return try await contentIterator.next()
        } catch {
            log(.warning, error)
            return nil
        }
    }

    // MARK: - Lookahead (after-snippet context)

    /// Pre-reads elements from the ContentIterator into `lookaheadQueue` until
    /// at least `snippetLength` chars of same-resource text are queued, or we
    /// reach a resource boundary or exhaustion.
    ///
    /// The boundary element (if any) is appended to the queue for normal
    /// processing later but does NOT count toward the lookahead budget.
    private func fillLookahead(currentHREF: AnyURL?) async {
        var textCount = lookaheadQueue
            .compactMap { $0 as? TextContentElement }
            .filter { $0.locator.href == currentHREF }
            .reduce(0) { $0 + $1.text.count }

        while textCount < snippetLength + snippetWordOvershootMargin {
            guard let el = await rawNextElement() else { break }
            lookaheadQueue.append(el)
            guard let textEl = el as? TextContentElement, !textEl.segments.isEmpty else { continue }
            guard textEl.locator.href == currentHREF else { break }
            textCount += textEl.text.count
        }
    }

    /// Returns up to `snippetLength` chars of text from queued elements that
    /// belong to the same resource as `currentHREF`.
    private func afterContextText(currentHREF: AnyURL?) -> String {
        var text = ""
        for el in lookaheadQueue {
            guard let textEl = el as? TextContentElement, !textEl.segments.isEmpty else { continue }
            guard textEl.locator.href == currentHREF else { break }
            text += (text.isEmpty ? "" : " ") + textEl.text
            if text.count >= snippetLength + snippetWordOvershootMargin { break }
        }
        return String(text.prefix(snippetLength + snippetWordOvershootMargin))
    }

    // MARK: - Core algorithm

    /// Processes one `TextContentElement`, returning any locators whose matches
    /// are safely outside the danger zone.
    private func processElement(_ element: TextContentElement, afterContext: String) async -> [Locator] {
        let (elementText, elementUnits) = buildElementContext(from: element)
        guard !elementText.isEmpty else { return [] }

        let (searchText, searchUnits) = buildSearchContext(
            elementText: elementText,
            elementUnits: elementUnits
        )

        let searchTextCount = searchText.count
        let ranges = await searchAlgorithm.findRanges(
            of: query,
            options: options,
            in: searchText,
            language: currentLanguage
        )

        let dangerZoneStart = max(0, searchTextCount - tailCapacity)

        let emittedLocators = ranges.compactMap { range -> Locator? in
            guard !Task.isCancelled else { return nil }
            let startOffset = searchText.distance(from: searchText.startIndex, to: range.lowerBound)
            guard startOffset < dangerZoneStart else { return nil }
            return makeLocator(range: range, searchUnits: searchUnits, searchText: searchText,
                               afterContext: afterContext)
        }

        updateTail(from: searchText, searchUnits: searchUnits, searchTextCount: searchTextCount)

        // Append the committed prefix (everything before the new tail) to the
        // snippet context buffer so future elements have full before-context.
        let prefixCount = max(0, searchTextCount - tailCapacity)
        if prefixCount > 0 {
            let committed = String(searchText.prefix(prefixCount))
            snippetContextBuffer = String(
                (snippetContextBuffer.isEmpty ? committed : snippetContextBuffer + committed)
                    .suffix(snippetLength + snippetWordOvershootMargin)
            )
        }

        return emittedLocators
    }

    /// Builds text and units from a single element's segments.
    private func buildElementContext(from element: TextContentElement) -> (String, [SearchUnit]) {
        var text = ""
        var units: [SearchUnit] = []

        for segment in element.segments where !segment.text.isEmpty {
            let start = text.count
            text.append(contentsOf: segment.text)
            units.append(SearchUnit(
                locator: segment.locator,
                range: start ..< text.count,
                isSeparator: false
            ))
        }

        return (text, units)
    }

    /// Combines tail with current element text for cross-element matching.
    private func buildSearchContext(
        elementText: String,
        elementUnits: [SearchUnit]
    ) -> (text: String, units: [SearchUnit]) {
        guard !tail.isEmpty else {
            return (elementText, elementUnits)
        }

        let tailLen = tail.count
        let offset = tailLen + 1

        // Safe locator resolution: prefer elementUnits, fall back to tailUnits
        guard let separatorLocator = elementUnits.first?.locator ?? tailUnits.last?.locator else {
            // If both are empty, return element context without tail
            return (elementText, elementUnits)
        }

        let separatorUnit = SearchUnit(
            locator: separatorLocator,
            range: tailLen ..< offset,
            isSeparator: true
        )

        let shiftedUnits = elementUnits.map {
            SearchUnit(
                locator: $0.locator,
                range: ($0.range.lowerBound + offset) ..< ($0.range.upperBound + offset),
                isSeparator: false
            )
        }

        return (tail + " " + elementText, tailUnits + [separatorUnit] + shiftedUnits)
    }

    /// Updates tail state for the next iteration.
    private func updateTail(from searchText: String, searchUnits: [SearchUnit], searchTextCount: Int) {
        let newTailStartOffset = max(0, searchTextCount - tailCapacity)

        tail = String(searchText.suffix(min(tailCapacity, searchTextCount)))

        tailUnits = searchUnits.compactMap { unit -> SearchUnit? in
            let lo = max(unit.range.lowerBound, newTailStartOffset)
            let hi = unit.range.upperBound
            guard lo < hi else { return nil }
            return SearchUnit(
                locator: unit.locator,
                range: (lo - newTailStartOffset) ..< (hi - newTailStartOffset),
                isSeparator: unit.isSeparator
            )
        }
    }

    /// Searches the remaining `tail` with no danger zone, then clears it.
    private func flushTail() async -> [Locator] {
        guard !tail.isEmpty else { return [] }
        defer {
            tail = ""
            tailUnits = []
        }

        let ranges = await searchAlgorithm.findRanges(
            of: query,
            options: options,
            in: tail,
            language: currentLanguage
        )

        return ranges.compactMap { range -> Locator? in
            guard !Task.isCancelled else { return nil }
            // At resource boundary: no same-resource after-context available.
            return makeLocator(range: range, searchUnits: tailUnits, searchText: tail, afterContext: "")
        }
    }

    // MARK: - Locator construction

    private func makeLocator(
        range: Range<String.Index>,
        searchUnits: [SearchUnit],
        searchText: String,
        afterContext: String
    ) -> Locator? {
        let startOffset = searchText.distance(from: searchText.startIndex, to: range.lowerBound)

        let owningUnit = searchUnits.first { !$0.isSeparator && $0.range.contains(startOffset) }
            ?? searchUnits.first { !$0.isSeparator && $0.range.lowerBound > startOffset }
            ?? searchUnits.last(where: { !$0.isSeparator })

        guard let baseLocator = owningUnit?.locator else {
            return nil
        }

        let highlight = String(searchText[range])
        let (before, after) = makeSnippet(
            range: range,
            searchUnits: searchUnits,
            searchText: searchText,
            startOffset: startOffset,
            afterContext: afterContext
        )

        return strippedForSnippetPositioning(
            baseLocator.copy(text: { $0 = Locator.Text(after: after, before: before, highlight: highlight) })
        )
    }

    // FIXME: Temporary workaround – remove when SearchResultItem is introduced.
    //
    // Why it exists: snippets now span multiple content elements within the
    // same resource, to provide more context to the user in the user interface.
    // So the `cssSelector` in the locator's `locations` may point to a single
    // DOM node that does not contain the full before/after text. The renderer
    // would anchor to that node and fail to find the highlight when it extends
    // across sibling elements.
    //
    // In the future, we might introduce a dedicated `SearchResultItem` type
    // that carries both a full *display* snippet (crossing elements) and a
    // separate *precise* locator (with `cssSelector`) for navigation. When that
    // type is introduced:
    //   1. Restore the `cssSelector` in the locator produced by `makeLocator`.
    //   2. Move the cross-element snippet text into SearchResultItem's display
    //      field.
    //   3. Delete this method entirely.
    private func strippedForSnippetPositioning(_ locator: Locator) -> Locator {
        guard locator.locations.cssSelector != nil else {
            return locator
        }
        return locator.copy(locations: {
            $0.cssSelector = nil
        })
    }

    // FIXME: To restore after dropping strippedForSnippetPositioning
    /// Extracts `before` / `after` snippet text, stopping at element-separator
    /// boundaries and capping at `snippetLength` characters (word-bounded).
    /// Works around HTML-based content iterators that set a `cssSelector` in
    /// the locator's `locations`. When a match spans multiple content
    /// elements, the `cssSelector` anchors the renderer to a single DOM node,
    /// preventing it from finding the full highlight text across sibling
    /// nodes.
    ///
    /// Not all content services produce a `cssSelector` — this adjustment is
    /// a no-op when the key is absent.
    private func adjustedForCrossElementMatch(
        _ locator: Locator,
        startOffset: Int,
        endOffset: Int,
        searchUnits: [SearchUnit]
    ) -> Locator {
        let startUnit = searchUnits.first { !$0.isSeparator && $0.range.contains(startOffset) }
        let endUnit = searchUnits.last { !$0.isSeparator && $0.range.contains(endOffset - 1) }

        guard
            let startUnit, let endUnit,
            startUnit.range != endUnit.range,
            locator.locations.cssSelector != nil
        else {
            return locator
        }

        return locator.copy(locations: {
            $0.cssSelector = nil
        })
    }

    /// Builds the `before` and `after` snippet strings for a match.
    ///
    /// `before` is extended with `snippetContextBuffer` (text from earlier
    /// elements in the same resource). `after` is extended with `afterContext`
    /// (text from later elements, pre-read via the lookahead queue).
    private func makeSnippet(
        range: Range<String.Index>,
        searchUnits: [SearchUnit],
        searchText: String,
        startOffset: Int,
        afterContext: String
    ) -> (before: String?, after: String?) {
        let extendedBefore = snippetContextBuffer + searchText[searchText.startIndex ..< range.lowerBound]
        let before = extractSnippetBefore(
            text: extendedBefore,
            trimLeading: snippetContextBuffer.isEmpty && startOffset == 0
        )

        let endOffset = searchText.distance(from: searchText.startIndex, to: range.upperBound)
        let rawAfter = String(searchText[range.upperBound...])
        let extendedAfter = afterContext.isEmpty ? rawAfter : rawAfter + " " + afterContext
        let after = extractSnippetAfter(
            text: extendedAfter,
            trimTrailing: afterContext.isEmpty && endOffset == searchText.count
        )

        return (before, after)
    }

    private func extractSnippetBefore(text: String, trimLeading: Bool) -> String? {
        var result = ""
        var count = snippetLength

        for char in text.reversed() {
            guard count >= 0 || !char.isWhitespace else { break }
            count -= 1
            result.insert(char, at: result.startIndex)
        }

        if trimLeading {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result.isEmpty ? nil : result
    }

    private func extractSnippetAfter(text: String, trimTrailing: Bool) -> String? {
        var result = ""
        var count = snippetLength

        for char in text {
            guard count >= 0 || !char.isWhitespace else { break }
            count -= 1
            result.append(char)
        }

        if trimTrailing {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result.isEmpty ? nil : result
    }
}
