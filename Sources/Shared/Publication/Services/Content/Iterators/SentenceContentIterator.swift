//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension ContentAttributeKey {
    /// Marks a `TextContentElement` whose segments are already aligned on
    /// sentence boundaries, produced by the `SentenceContentIterator`.
    ///
    /// `makeTextContentTokenizer` returns such elements untouched, preserving
    /// the on-page `highlight` of their locators.
    static var sentenceAligned: ContentAttributeKey<Bool> {
        .init("sentenceAligned")
    }
}

/// A `ContentIterator` decorator which re-segments fixed-layout content
/// (PDF, EPUB FXL) into sentences, so that each returned `TextContentElement`
/// holds exactly one sentence.
///
/// Fixed-layout content is paginated by construction: a sentence is cut by
/// printed line breaks, by block element boundaries and by page boundaries,
/// and stray page text (page numbers, running headers) sits in the middle of
/// the reading flow. This iterator:
///
/// - decomposes the raw elements into fragments (a printed line of a PDF page
///   blob, or one segment of an FXL block element);
/// - marks page artifacts (via `PageArtifactDetector`) and hard breaks (via
///   `HardBreakDetector`), emitting them as standalone elements;
/// - joins the remaining body fragments into normalized logical text,
///   de-hyphenating word cuts, and tokenizes it into sentences;
/// - emits one element per sentence, with one segment per fragment the
///   sentence touches. Segments after the first carry the `continued`
///   attribute, and each keeps a locator targeting its own page.
///
/// The output is a pure function of the raw content: forward and backward
/// iteration produce the exact same stream of elements, in reverse order.
public actor SentenceContentIterator: ContentIterator, Loggable {
    private let buffered: BufferedContentIterator
    private let builder: SentenceRegionBuilder

    /// Maximum number of raw elements walked when fetching the head edge of a
    /// neighboring multi-element (FXL) page.
    private let neighborWalkCap = 32

    public init(
        iterator: ContentIterator,
        language: Language? = nil,
        artifactDetectors: [PageArtifactDetector] = [PageNumberArtifactDetector(), RunningHeaderArtifactDetector()],
        hardBreakDetectors: [HardBreakDetector] = [SpacedCapsHardBreakDetector(), HeadingHardBreakDetector(), StandalonePageHardBreakDetector()],
        textTokenizerFactory: @escaping @Sendable (Language?) -> TextTokenizer = {
            makeDefaultTextTokenizer(unit: .sentence, language: $0)
        }
    ) {
        buffered = BufferedContentIterator(iterator, capacity: 256)
        builder = SentenceRegionBuilder(
            language: language,
            artifactDetectors: artifactDetectors,
            hardBreakDetectors: hardBreakDetectors,
            tokenize: textTokenizerFactory(language)
        )
    }

    // MARK: - ContentIterator

    /// Output elements derived from a contiguous range of raw elements
    /// bounded by anchors, so that no sentence crosses two windows.
    private struct Window {
        var outputs: [SentenceOutput]
        var range: Range<Int>
    }

    private var window: Window?

    /// Index of the last returned output in the current window, or nil when
    /// the cursor sits between two outputs without having returned one on
    /// this side (window entry, mid-start).
    private var last: Int?

    /// When `last` is nil, the cursor sits right before this output index.
    private var entryIndex = 0

    private var initialized = false

    public func next() async throws -> ContentElement? {
        try await initializeIfNeeded()
        guard var current = window else {
            return nil
        }
        var target = last.map { $0 + 1 } ?? entryIndex
        while target >= current.outputs.count {
            guard let nextWindow = try await window(startingAt: current.range.upperBound) else {
                return nil
            }
            window = nextWindow
            current = nextWindow
            last = nil
            entryIndex = 0
            target = 0
        }
        last = target
        return current.outputs[target].element
    }

    public func previous() async throws -> ContentElement? {
        try await initializeIfNeeded()
        guard var current = window else {
            return nil
        }
        var target = last.map { $0 - 1 } ?? (entryIndex - 1)
        while target < 0 {
            guard let previousWindow = try await window(containing: current.range.lowerBound - 1) else {
                return nil
            }
            window = previousWindow
            current = previousWindow
            last = nil
            entryIndex = previousWindow.outputs.count
            target = previousWindow.outputs.count - 1
        }
        last = target
        return current.outputs[target].element
    }

    /// Positions the cursor on the window containing the iteration start.
    ///
    /// When starting mid-publication, the cursor is placed right before the
    /// first output touching the first raw element, so that `next()` returns
    /// the full sentence containing the start position — even if it began on
    /// a previous page — and `previous()` returns the element before it.
    private func initializeIfNeeded() async throws {
        guard !initialized else {
            return
        }
        initialized = true
        if try await raw(at: 0) != nil {
            guard let start = try await window(containing: 0) else {
                return
            }
            window = start
            last = nil
            entryIndex = start.outputs.firstIndex { $0.maxElementCoordinate >= 0 }
                ?? start.outputs.count
        } else if try await raw(at: -1) != nil {
            // Starting at the very end of the publication, for backward
            // iteration.
            guard let start = try await window(containing: -1) else {
                return
            }
            window = start
            last = nil
            entryIndex = start.outputs.count
        }
    }

    // MARK: - Raw access

    private func raw(at coordinate: Int) async throws -> ContentElement? {
        try await buffered.element(atCoordinate: coordinate)
    }

    // MARK: - Windows

    private var windowCache = FIFOCache<Int, Window>(capacity: 8)

    /// Builds the window starting at the given raw coordinate, which must be
    /// an anchor boundary: a run of page runs extended while the seams
    /// between them are bridged by a sentence.
    private func window(startingAt start: Int) async throws -> Window? {
        if let cached = windowCache[start] {
            return cached
        }
        guard let element = try await raw(at: start) else {
            return nil
        }

        let window: Window
        if element is TextContentElement {
            var runs: [PageRun] = []
            var end = start
            while true {
                let run = try await pageRun(startingAt: end)
                runs.append(run)
                end = run.end
                guard let next = try await raw(at: end), next is TextContentElement else {
                    break
                }
                if try await isSeamAnchor(at: end) {
                    break
                }
            }
            window = try Window(outputs: builder.outputs(for: runs), range: start ..< end)
        } else {
            window = Window(
                outputs: [SentenceOutput(
                    element: element,
                    sortKey: .init(elementCoordinate: start, fragmentIndex: -1, charOffset: 0),
                    maxElementCoordinate: start
                )],
                range: start ..< start + 1
            )
        }
        windowCache[start] = window
        return window
    }

    /// Returns the window containing the given raw coordinate, scanning
    /// backward to its opening anchor first.
    private func window(containing coordinate: Int) async throws -> Window? {
        guard try await raw(at: coordinate) != nil else {
            return nil
        }
        let start = try await windowStart(containing: coordinate)
        guard let window = try await window(startingAt: start) else {
            return nil
        }
        assert(window.range.contains(coordinate), "The window derivation is not consistent across directions")
        return window
    }

    /// Scans backward from `coordinate` to the nearest opening anchor: the
    /// start of the publication, a non-text neighbor, or an anchored seam.
    ///
    /// Bounded: at most 3 consecutive seams can be non-anchored (see
    /// `isSeamAnchor`), so the scan spans at most ~4 pages plus the seam
    /// lookback.
    private func windowStart(containing coordinate: Int) async throws -> Int {
        guard let element = try await raw(at: coordinate), element is TextContentElement else {
            return coordinate
        }
        var start = try await pageRunStart(containing: coordinate)
        while true {
            guard let previous = try await raw(at: start - 1), previous is TextContentElement else {
                return start
            }
            if try await isSeamAnchor(at: start) {
                return start
            }
            start = try await pageRunStart(containing: start - 1)
        }
    }

    // MARK: - Seam anchors

    private var bridgeCache = FIFOCache<Int, Bool>(capacity: 32)

    /// Returns whether the seam at the given junction forces a sentence
    /// boundary.
    ///
    /// A seam anchors when no sentence bridges it, or — to bound the size of
    /// a region — when its 3 preceding seams all raw-bridge. The cap uses raw
    /// bridge statuses, never effective anchors, so it needs no recursion and
    /// is direction-independent.
    private func isSeamAnchor(at seam: Int) async throws -> Bool {
        guard try await rawBridge(at: seam) else {
            return true
        }
        var current = seam
        for _ in 0 ..< 3 {
            guard
                let previous = try await previousSeam(before: current),
                try await rawBridge(at: previous)
            else {
                return false
            }
            current = previous
        }
        return true
    }

    /// Returns the coordinate of the seam preceding the given one, or nil at
    /// a hard boundary (publication start, non-text element).
    private func previousSeam(before seam: Int) async throws -> Int? {
        let start = try await pageRunStart(containing: seam - 1)
        guard let previous = try await raw(at: start - 1), previous is TextContentElement else {
            return nil
        }
        return start
    }

    /// Returns whether a sentence spans the seam at the given junction,
    /// joining the two surrounding page bodies and re-tokenizing them.
    private func rawBridge(at seam: Int) async throws -> Bool {
        if let cached = bridgeCache[seam] {
            return cached
        }
        let leftStart = try await pageRunStart(containing: seam - 1)
        let left = try await pageRun(startingAt: leftStart)
        let right = try await pageRun(startingAt: seam)
        let result = try builder.rawBridge(leftFragments: left.fragments, rightFragments: right.fragments)
        bridgeCache[seam] = result
        return result
    }

    // MARK: - Page runs

    private var runCache = FIFOCache<Int, PageRun>(capacity: 16)

    /// Returns the coordinate of the first element of the page containing
    /// `coordinate`.
    private func pageRunStart(containing coordinate: Int) async throws -> Int {
        guard
            let element = try await raw(at: coordinate),
            let text = element as? TextContentElement
        else {
            return coordinate
        }
        let page = PageIdentity(of: text)
        var start = coordinate
        while
            let previous = try await raw(at: start - 1),
            let previousText = previous as? TextContentElement,
            PageIdentity(of: previousText) == page
        {
            start -= 1
        }
        return start
    }

    /// Assembles and classifies the fragments of the page starting at the
    /// given coordinate.
    private func pageRun(startingAt start: Int) async throws -> PageRun {
        if let cached = runCache[start] {
            return cached
        }
        guard let firstText = try await raw(at: start) as? TextContentElement else {
            assertionFailure("pageRun(startingAt:) called on a non-text coordinate")
            return PageRun(page: PageIdentity(href: "", pageFragment: nil), start: start, end: start, fragments: [], passthroughs: [])
        }
        let page = PageIdentity(of: firstText)

        var fragments: [Fragment] = []
        var passthroughs: [(coordinate: Int, element: ContentElement)] = []
        var end = start
        while
            let element = try await raw(at: end),
            let text = element as? TextContentElement,
            PageIdentity(of: text) == page
        {
            let elementFragments = builder.fragments(of: text, at: end)
            if elementFragments.isEmpty {
                passthroughs.append((end, element))
            } else {
                fragments += elementFragments
            }
            end += 1
        }

        var run = PageRun(
            page: page,
            start: start,
            end: end,
            fragments: fragments,
            passthroughs: passthroughs
        )
        let neighbors = try await neighborEdges(around: run)
        builder.classify(&run.fragments, neighbors: neighbors)

        if let width = pageProgressionWidth(of: run, firstLocator: firstText.locator) {
            for i in run.fragments.indices {
                run.fragments[i].progressionWidth = width
            }
        }

        runCache[start] = run
        return run
    }

    // MARK: - Neighbor context

    /// Fetches the edge texts of the pages surrounding a run, used by
    /// artifact detectors requiring neighbors (running headers).
    private func neighborEdges(around run: PageRun) async throws -> NeighborEdges {
        var edges = NeighborEdges()
        if let previous = try await pageEdgeTexts(of: run.start - 1, walkingBackward: true) {
            edges.previousHead = previous.head
            edges.previousTail = previous.tail
        }
        if let next = try await pageEdgeTexts(of: run.end, walkingBackward: false) {
            edges.nextHead = next.head
            edges.nextTail = next.tail
        }
        return edges
    }

    /// Returns the head and tail edge texts of the page containing
    /// `coordinate`, walking away from the adjacent run.
    ///
    /// The walk is capped for multi-element (FXL) pages: the far edge may be
    /// unknown for very large pages, which detectors must tolerate.
    private func pageEdgeTexts(of coordinate: Int, walkingBackward: Bool) async throws -> (head: [String], tail: [String])? {
        guard
            let element = try await raw(at: coordinate),
            let text = element as? TextContentElement
        else {
            return nil
        }
        let page = PageIdentity(of: text)
        if page.isPageBlob {
            let lines = (text.text ?? "").components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let max = SentenceRegionBuilder.maxArtifactsPerEdge
            return (head: Array(lines.prefix(max)), tail: Array(lines.suffix(max)))
        }

        var texts: [String] = []
        var reachedFarEdge = false
        var next = coordinate
        for _ in 0 ..< neighborWalkCap {
            guard
                let element = try await raw(at: next),
                let text = element as? TextContentElement,
                PageIdentity(of: text) == page
            else {
                reachedFarEdge = true
                break
            }
            if let elementText = text.text?.trimmingCharacters(in: .whitespacesAndNewlines), !elementText.isEmpty {
                texts.append(elementText)
            }
            next += walkingBackward ? -1 : 1
        }

        // `texts` is ordered from the near edge outward.
        let max = SentenceRegionBuilder.maxArtifactsPerEdge
        let near = Array(texts.prefix(max))
        let far = reachedFarEdge ? Array(texts.suffix(max).reversed()) : []
        return walkingBackward
            ? (head: far, tail: near)
            : (head: near, tail: far)
    }

    // MARK: - PDF progressions

    /// Progression span of a PDF page bracket in its resource, derived from
    /// the page number and progression of its locator.
    ///
    /// The resource iterator produces `progression == (N - 1) / pageCount`
    /// for page N, so the bracket width is recoverable from any page but the
    /// first. Single-page brackets at progression 0 are left uninterpolated.
    private func pageProgressionWidth(of run: PageRun, firstLocator: Locator) -> Double? {
        guard
            run.page.isPageBlob,
            let fragment = run.page.pageFragment,
            let number = Int(fragment.dropFirst("page=".count)),
            number > 1,
            let progression = firstLocator.locations.progression,
            progression > 0
        else {
            return nil
        }
        return progression / Double(number - 1)
    }
}

// MARK: - FIFO cache

/// A tiny fixed-capacity cache evicting the oldest inserted entries first.
///
/// Purely an optimization: every cached value is a pure function of the raw
/// content, so eviction never changes the produced elements.
private struct FIFOCache<Key: Hashable, Value> {
    private let capacity: Int
    private var values: [Key: Value] = [:]
    private var order: [Key] = []

    init(capacity: Int) {
        self.capacity = capacity
    }

    subscript(key: Key) -> Value? {
        get { values[key] }
        set {
            guard let newValue else {
                return
            }
            if values.updateValue(newValue, forKey: key) == nil {
                order.append(key)
                while order.count > capacity {
                    values.removeValue(forKey: order.removeFirst())
                }
            }
        }
    }
}
