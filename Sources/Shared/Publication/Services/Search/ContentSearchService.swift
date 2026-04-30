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
    ///     sanatized text.
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

    /// Character-count range (from the start of the owning search string).
    let range: Range<Int>

    /// `true` when this unit represents the artificial space separator inserted
    /// between adjacent elements in the tail-carry search text.
    let isSeparator: Bool
}

private class Iterator: SearchIterator, Loggable {
    private(set) var resultCount: Int? = 0

    private let contentIterator: ContentIterator
    private let language: Language?
    private let snippetLength: Int
    private let searchAlgorithm: StringSearchAlgorithm
    private let query: String
    private let options: SearchOptions

    // Tail-carry state

    private var tail: String = ""
    private var tailUnits: [SearchUnit] = []

    /// Number of characters kept as tail between elements.
    /// For plain query: `query.count - 1`; regex: capped at 256.
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
        self.language = language
        self.snippetLength = snippetLength
        self.searchAlgorithm = searchAlgorithm
        self.query = query
        self.options = options ?? SearchOptions()
        tailCapacity = (options?.regularExpression ?? false)
            ? 256
            : max(0, query.count - 1)
    }

    // MARK: next()

    func next() async -> SearchResult<LocatorCollection?> {
        while let element = await nextElement() {
            guard !Task.isCancelled else {
                return partialResult()
            }

            guard
                let element = element as? TextContentElement,
                !(element.text ?? "").isEmpty
            else {
                continue
            }

            if element.locator.href != currentHREF {
                // Resource boundary: flush deferred tail matches.
                let tailLocators = await flushTail()
                pendingLocators.append(contentsOf: tailLocators)

                if currentHREF != nil, !pendingLocators.isEmpty {
                    // Emit the completed resource batch, then seed the next.
                    let batch = pendingLocators
                    pendingLocators = []
                    currentHREF = element.locator.href
                    let newLocators = await processElement(element)
                    pendingLocators.append(contentsOf: newLocators)
                    resultCount = (resultCount ?? 0) + batch.count
                    return .success(LocatorCollection(locators: batch))
                }
                currentHREF = element.locator.href
            }

            let newLocators = await processElement(element)
            pendingLocators.append(contentsOf: newLocators)
        }

        // Content exhausted — flush any remaining deferred matches.
        let tailLocators = await flushTail()
        pendingLocators.append(contentsOf: tailLocators)

        if !pendingLocators.isEmpty {
            let batch = pendingLocators
            pendingLocators = []
            resultCount = (resultCount ?? 0) + batch.count
            return .success(LocatorCollection(locators: batch))
        }
        return .success(nil)
    }

    /// Returns whatever is in `pendingLocators` as a partial result (used on
    /// cancellation).
    private func partialResult() -> SearchResult<LocatorCollection?> {
        guard !pendingLocators.isEmpty else { return .success(nil) }
        let batch = pendingLocators
        pendingLocators = []
        resultCount = (resultCount ?? 0) + batch.count
        return .success(LocatorCollection(locators: batch))
    }

    /// Advances the content iterator, returning `nil` on normal exhaustion
    /// **or** on an iterator error (which is logged but not propagated so
    /// callers treat it as EOF).
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
    /// are safely outside the danger zone (i.e., cannot be superseded by a
    /// cross-element match in the next iteration).
    private func processElement(_ element: TextContentElement) async -> [Locator] {
        // Build element text and per-segment offset map.
        var elementText = ""
        var elementUnits: [SearchUnit] = []

        for segment in element.segments {
            guard !segment.text.isEmpty else { continue }
            let start = elementText.count
            elementText.append(contentsOf: segment.text)
            let end = elementText.count
            elementUnits.append(SearchUnit(locator: segment.locator, range: start ..< end, isSeparator: false))
        }

        guard !elementText.isEmpty else { return [] }

        // Build combined search text: tail + " " + elementText (or just
        // elementText).
        let searchText: String
        let searchUnits: [SearchUnit]

        if tail.isEmpty {
            searchText = elementText
            searchUnits = elementUnits
        } else {
            let tailLen = tail.count
            searchText = tail + " " + elementText

            let separatorUnit = SearchUnit(
                locator: elementUnits.first?.locator ?? tailUnits.last!.locator,
                range: tailLen ..< tailLen + 1,
                isSeparator: true
            )
            let shiftedElementUnits = elementUnits.map { (unit: SearchUnit) -> SearchUnit in
                SearchUnit(
                    locator: unit.locator,
                    range: (unit.range.lowerBound + tailLen + 1) ..< (unit.range.upperBound + tailLen + 1),
                    isSeparator: false
                )
            }
            searchUnits = tailUnits + [separatorUnit] + shiftedElementUnits
        }

        let searchTextCount = searchText.count
        let currentLanguage = options.language ?? language
        let ranges = await searchAlgorithm.findRanges(of: query, options: options, in: searchText, language: currentLanguage)

        // Only emit matches whose start is before the danger zone (last
        // `tailCapacity` chars). Matches starting in the danger zone are
        // deferred – they may form a cross-element match in the next iteration
        // when we prepend this tail.
        let dangerZoneStartOffset = searchTextCount - min(tailCapacity, searchTextCount)

        var emittedLocators: [Locator] = []
        for range in ranges {
            guard !Task.isCancelled else { break }
            let startOffset = searchText.distance(from: searchText.startIndex, to: range.lowerBound)
            if startOffset < dangerZoneStartOffset,
               let locator = makeLocator(range: range, searchUnits: searchUnits, searchText: searchText)
            {
                emittedLocators.append(locator)
            }
        }

        // Update tail: keep the last `tailCapacity` characters of the combined
        // text.
        let newTailStartOffset = searchTextCount - min(tailCapacity, searchTextCount)
        let newTailStartIndex = searchText.index(searchText.startIndex, offsetBy: newTailStartOffset)
        tail = String(searchText[newTailStartIndex...])

        // Rebuild tailUnits with ranges re-based to the new tail's start offset.
        tailUnits = searchUnits.compactMap { (unit: SearchUnit) -> SearchUnit? in
            let lo = max(unit.range.lowerBound, newTailStartOffset)
            let hi = unit.range.upperBound
            guard lo < hi else { return nil }
            return SearchUnit(
                locator: unit.locator,
                range: (lo - newTailStartOffset) ..< (hi - newTailStartOffset),
                isSeparator: unit.isSeparator
            )
        }

        return emittedLocators
    }

    /// Searches the remaining `tail` with no danger zone (all matches emitted),
    /// then clears it.
    ///
    /// Called at resource boundaries and after content is exhausted to avoid
    /// silently dropping deferred matches.
    private func flushTail() async -> [Locator] {
        guard !tail.isEmpty else { return [] }
        defer {
            tail = ""
            tailUnits = []
        }

        let currentLanguage = options.language ?? language
        let ranges = await searchAlgorithm.findRanges(of: query, options: options, in: tail, language: currentLanguage)

        return ranges.compactMap { (range: Range<String.Index>) -> Locator? in
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

        // Find the first non-separator unit that contains the match start.
        // Fall back to the next unit after the start (match starts at a
        // separator edge), or the last non-separator unit as a last resort.
        var owningUnit = searchUnits.first(where: { !$0.isSeparator && $0.range.contains(startOffset) })
        if owningUnit == nil {
            owningUnit = searchUnits.first(where: { !$0.isSeparator && $0.range.lowerBound > startOffset })
        }
        if owningUnit == nil {
            owningUnit = searchUnits.last(where: { !$0.isSeparator })
        }

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

        return baseLocator.copy(text: { $0 = Locator.Text(after: after, before: before, highlight: highlight) })
    }

    /// Extracts `before` / `after` snippet text, stopping at element-separator
    /// boundaries and capping at `snippetLength` characters (word-bounded).
    private func makeSnippet(
        range: Range<String.Index>,
        searchUnits: [SearchUnit],
        searchText: String,
        startOffset: Int
    ) -> (before: String?, after: String?) {
        let endOffset = searchText.distance(from: searchText.startIndex, to: range.upperBound)

        // Context region: bounded by the nearest separators on each side.
        let prevSepUpperBound = searchUnits
            .filter { $0.isSeparator && $0.range.upperBound <= startOffset }
            .map(\.range.upperBound)
            .max() ?? 0
        let nextSepLowerBound = searchUnits
            .filter { $0.isSeparator && $0.range.lowerBound >= endOffset }
            .map(\.range.lowerBound)
            .min() ?? searchText.count

        let contextStart = searchText.index(searchText.startIndex, offsetBy: prevSepUpperBound)
        let contextEnd = searchText.index(searchText.startIndex, offsetBy: nextSepLowerBound)

        var before = ""
        var count = snippetLength
        for char in searchText[contextStart ..< range.lowerBound].reversed() {
            guard count >= 0 || !char.isWhitespace else { break }
            count -= 1
            before.insert(char, at: before.startIndex)
        }
        if prevSepUpperBound == 0 {
            before = before.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var after = ""
        count = snippetLength
        for char in searchText[range.upperBound ..< contextEnd] {
            guard count >= 0 || !char.isWhitespace else { break }
            count -= 1
            after.append(char)
        }
        if nextSepLowerBound == searchText.count {
            after = after.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (before.isEmpty ? nil : before, after.isEmpty ? nil : after)
    }
}
