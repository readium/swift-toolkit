//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Implementation of `SearchService` using the Content API (`ContentService`).
///
/// It supports cross-element matching within the same resource via a
/// *sliding window* over the resource's concatenated element texts. The window
/// maintains a *danger zone* (last *T* characters) where matches are deferred
/// to the next iteration, enabling queries that span element boundaries (e.g.,
/// `<p>The quick</p><p>brown fox.</p>` matches "quick brown").
///
/// Cross-resource matching is intentionally not supported (the window is
/// flushed at every resource boundary).
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

// MARK: - Sliding Window Iterator

/// A segment of text from a single content element, stored in the sliding
/// window. Each entry tracks the element's concatenated segment text, its
/// owning locator, and its character offset within the window's joined text.
///
/// `startOffset` is window-relative: it is valid against the current
/// `windowText` and is rebased when front-trimming occurs.
private struct ElementEntry {
    /// Concatenated text of all non-empty segments in this element.
    let text: String

    /// Per-segment locators and their character ranges within `text`.
    let segments: [(locator: Locator, range: Range<Int>)]

    /// Window-relative offset where this entry's text begins. Rebased on trim.
    var startOffset: Int
}

private final class Iterator: SearchIterator, Loggable {
    private(set) var resultCount: Int? = 0

    private let contentIterator: ContentIterator
    private let snippetLength: Int
    private let searchAlgorithm: StringSearchAlgorithm
    private let query: String
    private let options: SearchOptions
    private let currentLanguage: Language?

    /// Danger-zone capacity used for regex queries (heuristic).
    private static let regexTailCapacity = 256

    /// Number of characters at the end of the searchable slice that form the
    /// *danger zone*. Matches starting in this zone are deferred to the next
    /// iteration because the query might extend into the following element,
    /// potentially yielding a longer or different match. At resource boundaries
    /// (or content exhaustion), the danger zone is flushed with no deferral.
    ///
    /// For plain text: `max(0, query.count - 1)`.
    /// For regex: `regexTailCapacity` (heuristic).
    private let tailCapacity: Int

    /// Extra characters stored beyond `snippetLength` in the context buffers.
    /// Ensures word-boundary rounding in `extractSnippetBefore/After` — which
    /// may overshoot `snippetLength` by up to one word — never reaches a
    /// hard-truncated buffer edge.
    private let snippetWordOvershootMargin = 100

    // MARK: Sliding window state

    /// The ordered entries currently in the window. Grows by appending new
    /// elements; shrinks via front-trimming when the retained snippet prefix
    /// exceeds its budget.
    private var entries: [ElementEntry] = []

    /// Cached concatenation of all entry texts joined by single-space
    /// separators. Grows by appending; prefix may be dropped during trim.
    private var windowText: String = ""

    /// Character count of `windowText`.
    private var windowTextCount: Int = 0

    /// Character offset where the searchable slice begins. Everything before
    /// this offset is the *retained snippet slice* — kept only for
    /// before-snippet extraction, never searched.
    private var searchFloor: Int = 0

    /// Character offset where the searchable slice ends. Text beyond this
    /// offset is the *lookahead slice* — read ahead for after-snippet context,
    /// not searched until the processing frontier advances.
    private var searchCeiling: Int = 0

    /// Whether the window starts at the very beginning of the current resource
    /// (i.e., no text was trimmed from before the first entry). Used to
    /// determine whether to trim leading whitespace from before-snippets.
    private var isAtResourceStart: Bool = true

    // MARK: Per-resource batching

    private var currentHREF: AnyURL?

    /// Locators found so far in the current batch, waiting to be returned by
    /// the next `emitBatch()` call. Flushed at resource boundaries and on
    /// content exhaustion.
    private var pendingLocators: [Locator] = []

    /// Elements read ahead from the ContentIterator that have not yet been
    /// appended to the window. Used to peek at resource boundaries without
    /// consuming the element.
    private var lookaheadBuffer: [ContentElement] = []

    fileprivate init(
        contentIterator: ContentIterator,
        language: Language?,
        snippetLength: Int,
        searchAlgorithm: StringSearchAlgorithm,
        query: String,
        options: SearchOptions?
    ) {
        let options = options ?? SearchOptions()

        self.contentIterator = contentIterator
        self.snippetLength = snippetLength
        self.searchAlgorithm = searchAlgorithm
        self.query = query
        self.options = options
        currentLanguage = options.language ?? language
        tailCapacity = (options.regularExpression ?? false)
            ? Iterator.regexTailCapacity
            : max(0, query.count - 1)
    }

    // MARK: - SearchIterator

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

            // Resource boundary detection.
            if
                textElement.locator.href != currentHREF,
                let batch = await handleResourceBoundary(newElement: textElement)
            {
                return batch
            }

            // Append element to window, advance searchCeiling, read ahead for
            // after-snippets, then search.
            appendToWindow(textElement)
            searchCeiling = windowTextCount
            await fillLookahead()
            await pendingLocators.append(contentsOf: search())
            trimFront()
        }

        // Content exhausted — flush remaining deferred matches.
        await pendingLocators.append(contentsOf: flush())
        return emitBatch()
    }

    // MARK: - Resource boundary handling

    /// Handles a resource-boundary transition. Flushes deferred matches for the
    /// old resource and resets the window for the new one.
    ///
    /// - Returns: A batch result if locators were accumulated, or `nil` to
    ///   signal fall-through (caller should continue processing `newElement`).
    private func handleResourceBoundary(newElement: TextContentElement) async -> SearchResult<LocatorCollection?>? {
        let flushed = await flush()
        pendingLocators.append(contentsOf: flushed)

        resetWindow()
        currentHREF = newElement.locator.href

        guard !pendingLocators.isEmpty else {
            return nil
        }

        let batch = pendingLocators
        pendingLocators = []

        // Start processing the new element immediately.
        appendToWindow(newElement)
        searchCeiling = windowTextCount
        await fillLookahead()
        await pendingLocators.append(contentsOf: search())
        trimFront()

        resultCount = (resultCount ?? 0) + batch.count
        return .success(LocatorCollection(locators: batch))
    }

    /// Returns accumulated `pendingLocators` as a batch, or `.success(nil)` if
    /// empty (signaling exhaustion).
    private func emitBatch() -> SearchResult<LocatorCollection?> {
        guard !pendingLocators.isEmpty else { return .success(nil) }
        let batch = pendingLocators
        pendingLocators = []
        resultCount = (resultCount ?? 0) + batch.count
        return .success(LocatorCollection(locators: batch))
    }

    // MARK: - Element reading

    /// Returns the next element, draining from `lookaheadBuffer` first.
    private func nextElement() async -> ContentElement? {
        if !lookaheadBuffer.isEmpty {
            return lookaheadBuffer.removeFirst()
        }
        return await rawNextElement()
    }

    /// Advances the ContentIterator, returning `nil` only on exhaustion.
    /// On error, logs the warning and retries so that a single failing element
    /// does not truncate the rest of the search results.
    private func rawNextElement() async -> ContentElement? {
        while !Task.isCancelled {
            do {
                return try await contentIterator.next()
            } catch {
                log(.warning, error)
            }
        }
        return nil
    }

    // MARK: - Window management

    /// Appends a text element to the window, updating `windowText` and
    /// `windowTextCount`. Does NOT advance `searchCeiling`.
    private func appendToWindow(_ element: TextContentElement) {
        var entryText = ""
        var segments: [(locator: Locator, range: Range<Int>)] = []

        for segment in element.segments where !segment.text.isEmpty {
            let start = entryText.count
            entryText.append(contentsOf: segment.text)
            segments.append((locator: segment.locator, range: start ..< entryText.count))
        }

        guard !entryText.isEmpty else { return }

        let startOffset: Int
        if windowText.isEmpty {
            startOffset = 0
        } else {
            // Space separator owned by this (following) entry.
            windowText.append(" ")
            windowTextCount += 1
            startOffset = windowTextCount
        }

        windowText.append(contentsOf: entryText)
        windowTextCount += entryText.count

        entries.append(ElementEntry(
            text: entryText,
            segments: segments,
            startOffset: startOffset
        ))
    }

    /// Resets the window for a new resource.
    private func resetWindow() {
        entries = []
        windowText = ""
        windowTextCount = 0
        searchFloor = 0
        searchCeiling = 0
        isAtResourceStart = true
    }

    /// Reads ahead into `lookaheadBuffer` until at least `snippetLength +
    /// snippetWordOvershootMargin` characters of same-resource lookahead text
    /// are available beyond `searchCeiling`, or a resource boundary / EOF is
    /// reached.
    private func fillLookahead() async {
        // Count text already available as lookahead: both the in-window slice
        // beyond searchCeiling and same-resource text in lookaheadBuffer.
        var textCount = max(0, windowTextCount - searchCeiling)
        for el in lookaheadBuffer {
            guard let textEl = el as? TextContentElement, !textEl.segments.isEmpty else { continue }
            guard textEl.locator.href == currentHREF else { break }
            textCount += textEl.text?.count ?? 0
        }

        let budget = snippetLength + snippetWordOvershootMargin

        while textCount < budget {
            guard !Task.isCancelled else { break }
            guard let el = await rawNextElement() else { break }
            lookaheadBuffer.append(el)
            guard let textEl = el as? TextContentElement, !textEl.segments.isEmpty else { continue }
            guard textEl.locator.href == currentHREF else { break }
            textCount += textEl.text?.count ?? 0
        }

        // Append same-resource lookahead elements to the window (they become
        // the lookahead slice — beyond searchCeiling, not searched yet).
        // Non-text elements and stale old-resource elements are skipped in-place
        // so they remain in the buffer for nextElement() to return in order.
        var i = lookaheadBuffer.startIndex
        while i < lookaheadBuffer.endIndex {
            let el = lookaheadBuffer[i]
            guard let textEl = el as? TextContentElement, !textEl.segments.isEmpty else {
                i += 1
                continue
            }
            guard textEl.locator.href == currentHREF else { break }
            lookaheadBuffer.remove(at: i)
            appendToWindow(textEl)
        }
    }

    /// Front-trims the window to bound memory. Keeps at most
    /// `snippetLength + snippetWordOvershootMargin` characters before
    /// `searchFloor` (the retained snippet slice).
    private func trimFront() {
        let retentionBudget = snippetLength + snippetWordOvershootMargin
        guard searchFloor > retentionBudget else { return }

        let trimTarget = searchFloor - retentionBudget

        // Find the first entry that is NOT fully within the trimmed prefix.
        var dropCount = 0
        for entry in entries {
            let entryEnd = entry.startOffset + entry.text.count
            if entryEnd <= trimTarget {
                dropCount += 1
            } else {
                break
            }
        }

        guard dropCount > 0 else { return }

        // Compute exact trim amount: up to the start of the first kept entry,
        // minus the preceding separator (if any).
        let firstKept = entries[dropCount]
        let trimAmount: Int
        if firstKept.startOffset > 0 {
            // Include the separator that precedes firstKept so that windowText
            // starts directly with the first kept entry's text after rebasing,
            // avoiding a leading space in before-snippets.
            trimAmount = firstKept.startOffset
        } else {
            trimAmount = 0
        }

        guard trimAmount > 0 else { return }

        // Drop leading entries.
        entries.removeFirst(dropCount)

        // Rebase offsets.
        for i in entries.indices {
            entries[i].startOffset -= trimAmount
        }
        searchFloor -= trimAmount
        searchCeiling -= trimAmount

        // Drop prefix from windowText.
        let trimIdx = windowText.index(windowText.startIndex, offsetBy: trimAmount)
        windowText = String(windowText[trimIdx...])
        windowTextCount -= trimAmount
        isAtResourceStart = false
    }

    // MARK: - Search

    /// Flushes all remaining deferred matches in the searchable slice with no
    /// danger zone (used at resource boundaries and content exhaustion).
    private func flush() async -> [Locator] {
        searchCeiling = windowTextCount
        return await search(dangerZoneCapacity: 0)
    }

    /// Searches the searchable slice `[searchFloor, searchCeiling)` and returns
    /// matches whose start offset is before the danger zone. Advances
    /// `searchFloor` past emitted text (up to the danger zone start).
    private func search() async -> [Locator] {
        await search(dangerZoneCapacity: tailCapacity)
    }

    /// Searches `[searchFloor, searchCeiling)` and emits all matches whose
    /// start offset falls before the danger zone. Advances `searchFloor` to the
    /// danger zone start (= `searchCeiling` when `dangerZoneCapacity` is 0).
    private func search(dangerZoneCapacity: Int) async -> [Locator] {
        guard searchCeiling > searchFloor else { return [] }

        let sliceStart = windowText.index(windowText.startIndex, offsetBy: searchFloor)
        let sliceEnd = windowText.index(windowText.startIndex, offsetBy: searchCeiling)
        let searchSlice = String(windowText[sliceStart ..< sliceEnd])

        let ranges = await searchAlgorithm.findRanges(
            of: query,
            options: options,
            in: searchSlice,
            language: currentLanguage
        )

        let sliceCount = searchCeiling - searchFloor
        let dangerZoneStart = max(0, sliceCount - dangerZoneCapacity)

        var locators: [Locator] = []
        for range in ranges {
            guard !Task.isCancelled else { break }
            let localStart = searchSlice.distance(from: searchSlice.startIndex, to: range.lowerBound)
            guard localStart < dangerZoneStart else { continue }

            let windowStart = searchFloor + localStart
            let windowEnd = searchFloor + searchSlice.distance(from: searchSlice.startIndex, to: range.upperBound)

            if let locator = makeLocator(matchStart: windowStart, matchEnd: windowEnd) {
                locators.append(locator)
            }
        }

        searchFloor += dangerZoneStart
        return locators
    }

    // MARK: - Locator construction

    /// Resolves a match's window-relative character range to a `Locator` with
    /// snippet text.
    ///
    /// Finds the owning entry (the entry whose range contains the match start),
    /// resolves the segment locator, and builds before/after snippets from the
    /// surrounding window text.
    private func makeLocator(matchStart: Int, matchEnd: Int) -> Locator? {
        guard let segmentLocator = resolveLocator(at: matchStart) else {
            return nil
        }

        let highlightStart = windowText.index(windowText.startIndex, offsetBy: matchStart)
        let highlightEnd = windowText.index(windowText.startIndex, offsetBy: matchEnd)
        let highlight = String(
            windowText[highlightStart ..< highlightEnd]
        )

        let before = extractSnippetBefore(matchStart: matchStart)
        let after = extractSnippetAfter(matchEnd: matchEnd)

        let locator = segmentLocator.copy(text: {
            $0 = Locator.Text(after: after, before: before, highlight: highlight)
        })

        return strippedForSnippetPositioning(locator)
    }

    /// Finds the segment locator for a given window offset.
    private func resolveLocator(at offset: Int) -> Locator? {
        guard let entry = entryContaining(offset: offset) else {
            return nil
        }

        // Compute offset within the entry's text.
        let localOffset = offset - entry.startOffset

        // Find the segment whose range contains localOffset.
        let segment = entry.segments.first { $0.range.contains(localOffset) }
            ?? entry.segments.first { $0.range.lowerBound > localOffset }
            ?? entry.segments.last

        return segment?.locator
    }

    /// Returns the entry whose text range contains the given window offset.
    private func entryContaining(offset: Int) -> ElementEntry? {
        entries
            .first { entry in
                let entryEnd = entry.startOffset + entry.text.count
                return offset >= entry.startOffset && offset < entryEnd
            }
            // Fallback: offset is on a separator — attribute to the next entry.
            ?? entries.first { $0.startOffset > offset }
            ?? entries.last
    }

    // MARK: - Snippet extraction

    /// Extracts the `before` snippet from window text preceding `matchStart`.
    ///
    /// Uses word-boundary rounding: reads up to `snippetLength` characters
    /// backwards, then extends up to `snippetWordOvershootMargin` additional
    /// characters to reach a whitespace boundary.
    ///
    /// Returns `nil` if the match is at the very beginning of a resource and
    /// the resulting text is empty after trimming.
    private func extractSnippetBefore(matchStart: Int) -> String? {
        guard matchStart > 0 else {
            return nil
        }

        let available = windowText[windowText.startIndex ..< windowText.index(windowText.startIndex, offsetBy: matchStart)]

        var chars: [Character] = []
        var count = snippetLength
        var overshoot = snippetWordOvershootMargin

        for char in available.reversed() {
            guard shouldContinueOvershooting(count: &count, overshoot: &overshoot, char: char) else { break }
            chars.append(char)
        }
        var result = String(chars.reversed())

        // If we captured all the way back to the start of the resource and
        // the text begins with whitespace, trim it — leading whitespace at
        // position 0 is an artifact of HTML serialization, not meaningful
        // context for the user.
        if isAtResourceStart && result.count == matchStart {
            let trimmed = result.drop(while: { $0.isWhitespace || $0.isNewline })
            result = String(trimmed)
        }

        return result.isEmpty ? nil : result
    }

    /// Extracts the `after` snippet from window text following `matchEnd`.
    ///
    /// Uses word-boundary rounding: reads up to `snippetLength` characters
    /// forwards, then extends up to `snippetWordOvershootMargin` additional
    /// characters to reach a whitespace boundary.
    ///
    /// Returns `nil` if the match is at the very end of a resource and the
    /// resulting text is empty after trimming.
    private func extractSnippetAfter(matchEnd: Int) -> String? {
        guard matchEnd < windowTextCount else {
            return nil
        }

        let afterStart = windowText.index(windowText.startIndex, offsetBy: matchEnd)
        let available = windowText[afterStart...]

        var result = ""
        var count = snippetLength
        var overshoot = snippetWordOvershootMargin

        for char in available {
            guard shouldContinueOvershooting(count: &count, overshoot: &overshoot, char: char) else { break }
            result.append(char)
        }

        // Trim trailing whitespace if we're at resource end (no more same-
        // resource elements in the lookahead buffer).
        let hasMoreSameResource = lookaheadBuffer.contains { el in
            guard let textEl = el as? TextContentElement, !textEl.segments.isEmpty else { return false }
            return textEl.locator.href == currentHREF
        }

        if !hasMoreSameResource && matchEnd + result.count == windowTextCount {
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result.isEmpty ? nil : result
    }

    /// Determines whether to continue iterating through characters for snippet extraction.
    /// Returns `false` when hitting whitespace after the budget is exhausted, or when
    /// the overshoot budget is exhausted.
    private func shouldContinueOvershooting(count: inout Int, overshoot: inout Int, char: Character) -> Bool {
        if count >= 0 {
            count -= 1
            return true
        } else if char.isWhitespace {
            return false
        } else {
            overshoot -= 1
            return overshoot >= 0
        }
    }

    // MARK: - CSS selector workaround

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
}
