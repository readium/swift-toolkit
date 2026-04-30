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
public class ContentSearchService: SearchService {
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

    init(
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

    // Per-resource batching state
    private var currentHREF: AnyURL?
    private var pendingLocators: [Locator] = []

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
        tailCapacity = (options?.regularExpression ?? false)
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
                let tailLocators = await flushTail()
                pendingLocators.append(contentsOf: tailLocators)

                if currentHREF != nil, !pendingLocators.isEmpty {
                    let batch = pendingLocators
                    pendingLocators = []
                    currentHREF = textElement.locator.href
                    await pendingLocators.append(contentsOf: processElement(textElement))
                    incrementResultCount(by: batch.count)
                    return .success(LocatorCollection(locators: batch))
                }
                currentHREF = textElement.locator.href
            }

            await pendingLocators.append(contentsOf: processElement(textElement))
        }

        // Content exhausted — flush any remaining deferred matches.
        await pendingLocators.append(contentsOf: flushTail())
        return emitBatch()
    }

    /// Returns whatever is in `pendingLocators` as a batch result.
    private func emitBatch() -> SearchResult<LocatorCollection?> {
        guard !pendingLocators.isEmpty else { return .success(nil) }
        let batch = pendingLocators
        pendingLocators = []
        incrementResultCount(by: batch.count)
        return .success(LocatorCollection(locators: batch))
    }

    /// Advances the content iterator, returning `nil` on normal exhaustion
    /// or on an iterator error (which is logged but not propagated).
    private func nextElement() async -> ContentElement? {
        do {
            return try await contentIterator.next()
        } catch {
            log(.warning, error)
            return nil
        }
    }

    // MARK: - Core algorithm

    /// Processes one `TextContentElement`, returning any locators whose matches
    /// are safely outside the danger zone.
    private func processElement(_ element: TextContentElement) async -> [Locator] {
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
            return makeLocator(range: range, searchUnits: searchUnits, searchText: searchText)
        }

        updateTail(from: searchText, searchUnits: searchUnits, searchTextCount: searchTextCount)

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
            return makeLocator(range: range, searchUnits: tailUnits, searchText: tail)
        }
    }

    // MARK: - Locator construction

    private func makeLocator(
        range: Range<String.Index>,
        searchUnits: [SearchUnit],
        searchText: String
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
            startOffset: startOffset
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

    /// Extracts `before` / `after` snippet text, allowing context to cross
    /// element boundaries within the same resource. Snippets are capped at
    /// `snippetLength` characters (word-bounded). Separator units are skipped
    /// during extraction but no longer act as hard boundaries.
    private func makeSnippet(
        range: Range<String.Index>,
        searchUnits: [SearchUnit],
        searchText: String,
        startOffset: Int
    ) -> (before: String?, after: String?) {
        let before = extractSnippetBefore(
            searchText: searchText,
            contextStart: searchText.startIndex,
            matchStart: range.lowerBound,
            trimLeading: startOffset == 0
        )

        let endOffset = searchText.distance(from: searchText.startIndex, to: range.upperBound)

        let after = extractSnippetAfter(
            searchText: searchText,
            matchEnd: range.upperBound,
            contextEnd: searchText.endIndex,
            trimTrailing: endOffset == searchText.count
        )

        return (before, after)
    }

    private func extractSnippetBefore(
        searchText: String,
        contextStart: String.Index,
        matchStart: String.Index,
        trimLeading: Bool
    ) -> String? {
        var result = ""
        var count = snippetLength

        for char in searchText[contextStart ..< matchStart].reversed() {
            guard count > 0 || !char.isWhitespace else { break }
            count -= 1
            result.insert(char, at: result.startIndex)
        }

        if trimLeading {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result.isEmpty ? nil : result
    }

    private func extractSnippetAfter(
        searchText: String,
        matchEnd: String.Index,
        contextEnd: String.Index,
        trimTrailing: Bool
    ) -> String? {
        var result = ""
        var count = snippetLength

        for char in searchText[matchEnd ..< contextEnd] {
            guard count > 0 || !char.isWhitespace else { break }
            count -= 1
            result.append(char)
        }

        if trimTrailing {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result.isEmpty ? nil : result
    }
}
