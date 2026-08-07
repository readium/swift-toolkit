//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Identifies the fixed-layout page an element belongs to.
///
/// Elements from different resources, or from the same resource with
/// different `page=` fragments (PDF), are on different pages.
struct PageIdentity: Hashable {
    let href: String
    let pageFragment: String?

    init(href: String, pageFragment: String?) {
        self.href = href
        self.pageFragment = pageFragment
    }

    init(of element: ContentElement) {
        href = element.locator.href.string
        pageFragment = element.locator.locations.fragments
            .first { $0.lowercased().hasPrefix("page=") }?
            .lowercased()
    }

    /// Whether the element holds the text of a whole page (PDF), as opposed
    /// to being one of several elements on its page (FXL).
    var isPageBlob: Bool {
        pageFragment != nil
    }
}

/// The atomic unit of sentence re-segmentation: a printed line of a PDF page
/// blob, or one segment of a fixed-layout block element.
struct Fragment {
    enum Kind {
        /// Regular reading-order text, re-segmented into sentences.
        case body
        /// Page-boundary noise, emitted as a standalone element skipped by TTS.
        case artifact(PageArtifactKind)
        /// Standalone display text (heading, title page line), emitted as its
        /// own element; sentences never merge across it.
        case hardBreak

        var isBody: Bool {
            if case .body = self { return true } else { return false }
        }

        var isArtifact: Bool {
            if case .artifact = self { return true } else { return false }
        }
    }

    var page: PageIdentity

    /// Virtual coordinate of the raw element this fragment comes from.
    var elementCoordinate: Int

    /// Index of this fragment among the fragments of its element.
    var indexInElement: Int

    /// Text as it appears on the page: a trimmed printed line (PDF blob) or a
    /// raw segment text (FXL).
    var text: String

    var sourceLocator: Locator
    var elementAttributes: [ContentAttribute]
    var segmentAttributes: [ContentAttribute]
    var role: TextContentElement.Role
    var kind: Kind = .body

    /// A blank line separates this fragment from the previous one on the
    /// page, forcing a sentence boundary.
    var paragraphGapBefore = false

    /// The fragment continues the previous one within the same element, with
    /// the original spacing preserved (FXL segments concatenate directly).
    var isContiguousWithPrevious = false

    /// Character offset of the fragment in its page blob, used to interpolate
    /// PDF progressions.
    var charOffsetInPage = 0

    /// Total character count of the page blob.
    var pageCharCount = 0

    /// Progression span of the page bracket in its resource, when known.
    var progressionWidth: Double?
}

/// A contiguous run of raw elements belonging to the same fixed-layout page.
struct PageRun {
    var page: PageIdentity
    /// Virtual coordinate of the first raw element of the run.
    var start: Int
    /// Virtual coordinate past the last raw element of the run.
    var end: Int
    /// Classified fragments of the run, in reading order.
    var fragments: [Fragment]
    /// Elements of the run producing no fragments (blank text elements),
    /// passed through unchanged.
    var passthroughs: [(coordinate: Int, element: ContentElement)]

    /// First few fragment texts, used as neighbor context when classifying
    /// the adjacent pages' artifacts.
    var headEdgeTexts: [String] {
        fragments.prefix(SentenceRegionBuilder.maxArtifactsPerEdge).map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Last few fragment texts, used as neighbor context when classifying
    /// the adjacent pages' artifacts.
    var tailEdgeTexts: [String] {
        fragments.suffix(SentenceRegionBuilder.maxArtifactsPerEdge).map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

/// Edge texts of the pages neighboring a page run, used by artifact detectors
/// requiring neighbors (running headers).
struct NeighborEdges {
    var previousHead: [String] = []
    var previousTail: [String] = []
    var nextHead: [String] = []
    var nextTail: [String] = []
}

/// An element produced by the re-segmentation, with its position in the
/// document used to order the output stream.
struct SentenceOutput {
    var element: ContentElement

    /// Position of the output's first fragment in the document.
    var sortKey: SortKey

    /// Virtual coordinate of the last raw element the output touches.
    var maxElementCoordinate: Int

    struct SortKey: Comparable {
        var elementCoordinate: Int
        var fragmentIndex: Int
        /// Character offset of the sentence in its region's logical text,
        /// disambiguating sentences starting in the same fragment.
        var charOffset: Int

        static func < (lhs: SortKey, rhs: SortKey) -> Bool {
            (lhs.elementCoordinate, lhs.fragmentIndex, lhs.charOffset)
                < (rhs.elementCoordinate, rhs.fragmentIndex, rhs.charOffset)
        }
    }
}

/// Pure sentence re-segmentation pipeline: decomposes raw fixed-layout
/// elements into fragments, classifies page artifacts and hard breaks, joins
/// fragments into normalized logical text and emits one `TextContentElement`
/// per sentence.
///
/// All functions are pure: the output only depends on the given fragments and
/// neighbor context, never on the order in which pages were visited.
struct SentenceRegionBuilder {
    /// Maximum number of page artifacts detected at each page edge.
    static let maxArtifactsPerEdge = 3

    /// Maximum amount of text considered on each side of a seam by the
    /// bridge test.
    static let seamChunkLength = 600

    /// Maximum number of fragments in a region: a sentence boundary is forced
    /// at the cap, bounding regions on pathological punctuation-less content.
    static let maxRegionFragments = 200

    /// Length of the `before` and `after` context snippets in the produced
    /// locators.
    static let contextSnippetLength = 50

    let language: Language?
    let artifactDetectors: [PageArtifactDetector]
    let hardBreakDetectors: [HardBreakDetector]
    let tokenize: TextTokenizer

    // MARK: - Fragmentation

    /// Decomposes a raw text element into fragments: one per printed line for
    /// a PDF page blob, one per segment for an FXL block element.
    func fragments(of element: TextContentElement, at coordinate: Int) -> [Fragment] {
        let page = PageIdentity(of: element)
        if page.isPageBlob {
            return blobFragments(of: element, page: page, at: coordinate)
        } else {
            return segmentFragments(of: element, page: page, at: coordinate)
        }
    }

    private func blobFragments(of element: TextContentElement, page: PageIdentity, at coordinate: Int) -> [Fragment] {
        let text = element.text ?? ""
        let baseAttributes = element.segments.first?.attributes ?? []
        var result: [Fragment] = []
        var offset = 0
        var pendingGap = false
        for line in text.components(separatedBy: "\n") {
            defer { offset += line.count + 1 }
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty {
                // Blank lines force a paragraph gap, but only between body
                // lines: page margins encoded as leading or trailing blank
                // lines must not disable seam merging.
                if !result.isEmpty {
                    pendingGap = true
                }
                continue
            }
            result.append(Fragment(
                page: page,
                elementCoordinate: coordinate,
                indexInElement: result.count,
                text: trimmedLine,
                sourceLocator: element.locator,
                elementAttributes: element.attributes,
                segmentAttributes: baseAttributes,
                role: element.role,
                paragraphGapBefore: pendingGap,
                charOffsetInPage: offset + line.prefix(while: \.isWhitespace).count,
                pageCharCount: text.count
            ))
            pendingGap = false
        }
        return result
    }

    private func segmentFragments(of element: TextContentElement, page: PageIdentity, at coordinate: Int) -> [Fragment] {
        var result: [Fragment] = []
        // Whitespace-only segments are folded into the neighboring fragment
        // to preserve the element's original spacing.
        var pendingBlank = ""
        for segment in element.segments {
            if segment.text.allSatisfy(\.isWhitespace) {
                if result.isEmpty {
                    pendingBlank += segment.text
                } else {
                    result[result.count - 1].text += segment.text
                }
                continue
            }
            result.append(Fragment(
                page: page,
                elementCoordinate: coordinate,
                indexInElement: result.count,
                text: pendingBlank + segment.text,
                sourceLocator: segment.locator,
                elementAttributes: element.attributes,
                segmentAttributes: segment.attributes,
                role: element.role,
                isContiguousWithPrevious: !result.isEmpty
            ))
            pendingBlank = ""
        }
        return result
    }

    // MARK: - Classification

    /// Marks the page artifacts sitting at the edges of a page run, then the
    /// hard breaks among the remaining body fragments.
    ///
    /// The classification is a pure function of the run's fragments and the
    /// neighboring pages' edge texts, so it is deterministic regardless of
    /// the direction of traversal.
    func classify(_ fragments: inout [Fragment], neighbors: NeighborEdges) {
        classifyArtifacts(&fragments, neighbors: neighbors)
        classifyHardBreaks(&fragments)
    }

    private func classifyArtifacts(_ fragments: inout [Fragment], neighbors: NeighborEdges) {
        var marked = 0
        var head = 0
        while marked < Self.maxArtifactsPerEdge, head < fragments.count {
            guard let kind = detectArtifact(
                in: fragments[head],
                edge: .head,
                previousEdgeLines: neighbors.previousHead,
                nextEdgeLines: neighbors.nextHead
            ) else {
                break
            }
            fragments[head].kind = .artifact(kind)
            marked += 1
            head += 1
        }

        marked = 0
        var tail = fragments.count - 1
        while marked < Self.maxArtifactsPerEdge, tail >= head {
            guard let kind = detectArtifact(
                in: fragments[tail],
                edge: .tail,
                previousEdgeLines: neighbors.previousTail,
                nextEdgeLines: neighbors.nextTail
            ) else {
                break
            }
            fragments[tail].kind = .artifact(kind)
            marked += 1
            tail -= 1
        }
    }

    /// Runs the artifact detectors on a fragment, pairing it with each of the
    /// neighboring pages' edge lines.
    private func detectArtifact(
        in fragment: Fragment,
        edge: PageArtifactCandidate.Edge,
        previousEdgeLines: [String],
        nextEdgeLines: [String]
    ) -> PageArtifactKind? {
        let text = fragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }
        let scope: PageArtifactCandidate.Scope = fragment.page.isPageBlob ? .line : .element

        for detector in artifactDetectors {
            if detector.requiresNeighbors {
                let previous: [String?] = previousEdgeLines.isEmpty ? [nil] : previousEdgeLines
                let next: [String?] = nextEdgeLines.isEmpty ? [nil] : nextEdgeLines
                for previousLine in previous {
                    for nextLine in next {
                        guard previousLine != nil || nextLine != nil else {
                            continue
                        }
                        if let kind = detector.detectArtifact(in: PageArtifactCandidate(
                            text: text,
                            edge: edge,
                            scope: scope,
                            previousPageEdgeText: previousLine,
                            nextPageEdgeText: nextLine
                        )) {
                            return kind
                        }
                    }
                }
            } else if let kind = detector.detectArtifact(in: PageArtifactCandidate(
                text: text,
                edge: edge,
                scope: scope,
                previousPageEdgeText: previousEdgeLines.first,
                nextPageEdgeText: nextEdgeLines.first
            )) {
                return kind
            }
        }
        return nil
    }

    private func classifyHardBreaks(_ fragments: inout [Fragment]) {
        let bodyCount = fragments.count(where: \.kind.isBody)
        var i = 0
        while i < fragments.count {
            guard fragments[i].kind.isBody else {
                i += 1
                continue
            }
            // FXL segments of the same element form one candidate; PDF lines
            // are individual candidates.
            var end = i + 1
            if !fragments[i].page.isPageBlob {
                while end < fragments.count,
                      fragments[end].elementCoordinate == fragments[i].elementCoordinate,
                      fragments[end].kind.isBody
                {
                    end += 1
                }
            }
            let candidate = HardBreakCandidate(
                text: fragments[i ..< end].map(\.text).joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                role: fragments[i].role,
                isWholePage: end - i == bodyCount
            )
            if hardBreakDetectors.contains(where: { $0.isHardBreak(candidate) }) {
                for k in i ..< end {
                    fragments[k].kind = .hardBreak
                }
            }
            i = end
        }
    }

    // MARK: - Bridge test

    /// Returns whether a sentence spans the seam between the two classified
    /// fragment runs: the tail of the left page joined with the head of the
    /// right page is re-tokenized, and the seam is bridged when a sentence
    /// token straddles it.
    func rawBridge(leftFragments: [Fragment], rightFragments: [Fragment]) throws -> Bool {
        let left = leftFragments.filter { !$0.kind.isArtifact }
        let right = rightFragments.filter { !$0.kind.isArtifact }

        var leftChunk: [Fragment] = []
        var count = 0
        for fragment in left.reversed() {
            leftChunk.insert(fragment, at: 0)
            count += fragment.text.count
            if count >= Self.seamChunkLength { break }
        }
        var rightChunk: [Fragment] = []
        count = 0
        for fragment in right {
            rightChunk.append(fragment)
            count += fragment.text.count
            if count >= Self.seamChunkLength { break }
        }
        guard !leftChunk.isEmpty, !rightChunk.isEmpty else {
            return false
        }

        let joined = join(leftChunk + rightChunk)
        guard let lastLeft = joined.fragments.dropLast(rightChunk.count).last else {
            return false
        }
        let seamIndex = lastLeft.range.upperBound
        let text = joined.text

        return try tokenize(text).contains { token in
            let lower = text.distance(from: text.startIndex, to: token.lowerBound)
            let upper = text.distance(from: text.startIndex, to: token.upperBound)
            return lower < seamIndex && upper > seamIndex
        }
    }

    // MARK: - Joining

    /// A fragment's contribution to a region's logical text.
    struct JoinedFragment {
        var fragment: Fragment

        /// Normalized text contributed to the logical text.
        var logicalText: String

        /// Character range of `logicalText` within the region's logical text.
        var range: Range<Int>

        /// How this fragment joins the previous one (nil for the first).
        var joiner: ContentContinuationJoiner?

        /// Whether a space character was inserted before this fragment in the
        /// logical text.
        var insertsSpace: Bool

        /// Whether a trailing hyphen was dropped during de-hyphenation; the
        /// on-page highlight keeps it.
        var droppedTrailingHyphen: Bool

        /// Number of characters trimmed from the head of the on-page text.
        var leadingTrimCount: Int
    }

    struct JoinResult {
        var text: String
        var fragments: [JoinedFragment]
    }

    /// Joins the fragments of a region into normalized logical text:
    /// contiguous same-element segments concatenate directly, hyphenated word
    /// cuts are re-joined without the hyphen, space-less scripts join
    /// directly, and everything else joins with a single space.
    func join(_ fragments: [Fragment]) -> JoinResult {
        let hardHyphens: Set<Character> = ["-", "\u{2010}"]
        let softHyphen: Character = "\u{00AD}"

        // First pass: per-fragment logical text and join decisions. Trailing
        // hyphens and whitespace are resolved on the previous fragment before
        // offsets are assigned.
        var joined: [JoinedFragment] = []
        for fragment in fragments {
            var logicalText: String
            var leadingTrimCount = 0
            var joiner: ContentContinuationJoiner?
            var insertsSpace = false

            // The contiguity flag only holds against the fragment's actual
            // element predecessor; when it was peeled off (classified as an
            // artifact or hard break), fall back to the regular joining rule.
            let isContiguous = fragment.isContiguousWithPrevious
                && joined.last.map {
                    $0.fragment.elementCoordinate == fragment.elementCoordinate
                        && $0.fragment.indexInElement == fragment.indexInElement - 1
                } == true

            if !joined.isEmpty, isContiguous {
                logicalText = fragment.text
                let boundaryHasWhitespace =
                    joined[joined.count - 1].logicalText.last?.isWhitespace == true
                        || fragment.text.first?.isWhitespace == true
                joiner = boundaryHasWhitespace ? .space : .direct
            } else {
                (logicalText, leadingTrimCount) = trimmingHeadCounting(fragment.text)
                if !joined.isEmpty {
                    var previous = joined[joined.count - 1]
                    previous.logicalText = trimmingTail(previous.logicalText)
                    if previous.logicalText.last == softHyphen
                        || (previous.logicalText.last.map { hardHyphens.contains($0) } == true
                            && logicalText.first?.isLowercase == true)
                    {
                        previous.logicalText.removeLast()
                        previous.droppedTrailingHyphen = true
                        joiner = .direct
                    } else if isSpacelessScript(effectiveLanguage(of: fragment)) {
                        joiner = .direct
                    } else {
                        joiner = .space
                        insertsSpace = true
                    }
                    joined[joined.count - 1] = previous
                }
            }

            joined.append(JoinedFragment(
                fragment: fragment,
                logicalText: logicalText,
                range: 0 ..< 0,
                joiner: joiner,
                insertsSpace: insertsSpace,
                droppedTrailingHyphen: false,
                leadingTrimCount: leadingTrimCount
            ))
        }
        if !joined.isEmpty {
            joined[joined.count - 1].logicalText = trimmingTail(joined[joined.count - 1].logicalText)
        }

        // Second pass: assemble the logical text and assign offsets.
        var text = ""
        var offset = 0
        for i in joined.indices {
            if joined[i].insertsSpace {
                text += " "
                offset += 1
            }
            let count = joined[i].logicalText.count
            joined[i].range = offset ..< offset + count
            text += joined[i].logicalText
            offset += count
        }
        return JoinResult(text: text, fragments: joined)
    }

    private func effectiveLanguage(of fragment: Fragment) -> Language? {
        attribute(.language, in: fragment.segmentAttributes)
            ?? attribute(.language, in: fragment.elementAttributes)
            ?? language
    }

    private func attribute<T: Hashable & Sendable>(_ key: ContentAttributeKey<T>, in attributes: [ContentAttribute]) -> T? {
        attributes.first { $0.key == key.key }?.value as? T
    }

    /// Whether words of the given language are not separated by spaces.
    private func isSpacelessScript(_ language: Language?) -> Bool {
        guard let code = language?.code.bcp47
            .split(separator: "-").first?
            .lowercased()
        else {
            return false
        }
        return ["zh", "ja", "th", "km", "lo", "my"].contains(code)
    }

    // MARK: - Output

    /// Produces the ordered output elements for a window of page runs: one
    /// element per sentence, plus standalone artifact, hard break and
    /// passthrough elements, sorted by first-fragment document position.
    func outputs(for runs: [PageRun]) throws -> [SentenceOutput] {
        var outputs: [SentenceOutput] = []
        for run in runs {
            for (coordinate, element) in run.passthroughs {
                outputs.append(SentenceOutput(
                    element: element,
                    sortKey: .init(elementCoordinate: coordinate, fragmentIndex: -1, charOffset: 0),
                    maxElementCoordinate: coordinate
                ))
            }
        }

        let fragments = runs.flatMap(\.fragments)
        var region: [Fragment] = []

        func closeRegion() throws {
            guard !region.isEmpty else { return }
            try outputs.append(contentsOf: sentenceOutputs(for: region))
            region = []
        }

        var i = 0
        while i < fragments.count {
            let fragment = fragments[i]
            switch fragment.kind {
            case let .artifact(kind):
                outputs.append(artifactOutput(fragment, kind: kind))
                i += 1

            case .hardBreak:
                try closeRegion()
                var end = i + 1
                while end < fragments.count,
                      fragments[end].elementCoordinate == fragment.elementCoordinate,
                      !fragments[end].kind.isBody, !fragments[end].kind.isArtifact
                {
                    end += 1
                }
                if let output = try hardBreakOutput(Array(fragments[i ..< end])) {
                    outputs.append(output)
                }
                i = end

            case .body:
                if fragment.paragraphGapBefore || region.count >= Self.maxRegionFragments {
                    try closeRegion()
                }
                region.append(fragment)
                i += 1
            }
        }
        try closeRegion()

        return outputs.sorted { $0.sortKey < $1.sortKey }
    }

    /// Tokenizes a region into sentences and emits one element per sentence.
    private func sentenceOutputs(for region: [Fragment]) throws -> [SentenceOutput] {
        let joined = join(region)
        let text = joined.text
        var outputs: [SentenceOutput] = []
        for token in try tokenize(text) {
            let lower = text.distance(from: text.startIndex, to: token.lowerBound)
            let upper = text.distance(from: text.startIndex, to: token.upperBound)
            guard upper > lower else { continue }
            if let output = sentenceOutput(in: joined, tokenRange: lower ..< upper) {
                outputs.append(output)
            }
        }
        return outputs
    }

    /// Builds the per-sentence element for a token of the region's logical
    /// text: one segment per fragment the sentence touches, with the
    /// normalized text as `segment.text` and the on-page form as the
    /// locator's `highlight`.
    private func sentenceOutput(in joined: JoinResult, tokenRange: Range<Int>) -> SentenceOutput? {
        let text = joined.text
        var segments: [TextContentElement.Segment] = []
        var first: JoinedFragment?
        var maxCoordinate = Int.min

        for jf in joined.fragments {
            guard
                jf.range.upperBound > tokenRange.lowerBound,
                jf.range.lowerBound < tokenRange.upperBound
            else {
                continue
            }
            let isFirst = first == nil
            let partStart = isFirst
                ? max(tokenRange.lowerBound, jf.range.lowerBound)
                : jf.range.lowerBound - (jf.insertsSpace ? 1 : 0)
            let partEnd = min(tokenRange.upperBound, jf.range.upperBound)
            guard partEnd > partStart else { continue }

            // Map the logical slice back to the on-page form.
            let sliceStart = max(partStart, jf.range.lowerBound) - jf.range.lowerBound
            let sliceEnd = partEnd - jf.range.lowerBound
            var highlightEnd = jf.leadingTrimCount + sliceEnd
            if sliceEnd == jf.logicalText.count, jf.droppedTrailingHyphen {
                highlightEnd += 1
            }
            let highlight = substring(
                jf.fragment.text,
                (jf.leadingTrimCount + sliceStart) ..< min(highlightEnd, jf.fragment.text.count)
            )
            let (before, after) = context(of: partStart ..< partEnd, in: text)

            var attributes = jf.fragment.segmentAttributes
            if !isFirst, let joiner = jf.joiner {
                attributes.append(ContentAttribute(key: .continued, value: joiner))
            }

            segments.append(TextContentElement.Segment(
                locator: locator(
                    for: jf.fragment,
                    characterOffset: jf.leadingTrimCount + sliceStart,
                    text: Locator.Text(after: after, before: before, highlight: highlight)
                ),
                text: substring(text, partStart ..< partEnd),
                attributes: attributes
            ))
            if isFirst {
                first = jf
            }
            maxCoordinate = max(maxCoordinate, jf.fragment.elementCoordinate)
        }

        guard let first, !segments.isEmpty else {
            return nil
        }

        let (before, after) = context(of: tokenRange, in: text)
        var attributes = first.fragment.elementAttributes
        attributes.append(ContentAttribute(key: .sentenceAligned, value: true))

        let element = TextContentElement(
            locator: locator(
                for: first.fragment,
                characterOffset: first.leadingTrimCount + max(0, tokenRange.lowerBound - first.range.lowerBound),
                text: Locator.Text(
                    after: after,
                    before: before,
                    highlight: substring(text, tokenRange)
                )
            ),
            role: first.fragment.role,
            segments: segments,
            attributes: attributes
        )
        return SentenceOutput(
            element: element,
            sortKey: .init(
                elementCoordinate: first.fragment.elementCoordinate,
                fragmentIndex: first.fragment.indexInElement,
                charOffset: tokenRange.lowerBound
            ),
            maxElementCoordinate: maxCoordinate
        )
    }

    private func artifactOutput(_ fragment: Fragment, kind: PageArtifactKind) -> SentenceOutput {
        let text = fragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attribute = ContentAttribute(key: .pageArtifact, value: kind)
        let locator = locator(
            for: fragment,
            characterOffset: 0,
            text: Locator.Text(highlight: text)
        )
        let element = TextContentElement(
            locator: locator,
            role: fragment.role,
            segments: [TextContentElement.Segment(
                locator: locator,
                text: text,
                attributes: fragment.segmentAttributes + [attribute]
            )],
            attributes: fragment.elementAttributes + [attribute]
        )
        return SentenceOutput(
            element: element,
            sortKey: .init(
                elementCoordinate: fragment.elementCoordinate,
                fragmentIndex: fragment.indexInElement,
                charOffset: 0
            ),
            maxElementCoordinate: fragment.elementCoordinate
        )
    }

    /// A hard break is emitted like a single-sentence element covering all
    /// its fragments, so it is spoken as one utterance and searchable.
    private func hardBreakOutput(_ fragments: [Fragment]) throws -> SentenceOutput? {
        let joined = join(fragments)
        guard !joined.text.isEmpty else {
            return nil
        }
        return sentenceOutput(in: joined, tokenRange: 0 ..< joined.text.count)
    }

    // MARK: - Text helpers

    private func locator(for fragment: Fragment, characterOffset: Int, text: Locator.Text) -> Locator {
        fragment.sourceLocator.copy(
            locations: {
                if let width = fragment.progressionWidth,
                   fragment.pageCharCount > 0,
                   let progression = $0.progression
                {
                    let fraction = Double(fragment.charOffsetInPage + characterOffset)
                        / Double(fragment.pageCharCount)
                    $0.progression = min(progression + width * fraction, progression + width)
                }
            },
            text: { $0 = text }
        )
    }

    private func context(of range: Range<Int>, in text: String) -> (before: String?, after: String?) {
        let count = text.count
        let before = substring(text, max(0, range.lowerBound - Self.contextSnippetLength) ..< range.lowerBound)
        let after = substring(text, range.upperBound ..< min(count, range.upperBound + Self.contextSnippetLength))
        return (before.isEmpty ? nil : before, after.isEmpty ? nil : after)
    }

    private func substring(_ string: String, _ range: Range<Int>) -> String {
        guard range.lowerBound >= 0, range.upperBound <= string.count, !range.isEmpty else {
            return ""
        }
        let start = string.index(string.startIndex, offsetBy: range.lowerBound)
        let end = string.index(start, offsetBy: range.count)
        return String(string[start ..< end])
    }

    private func trimmingHeadCounting(_ string: String) -> (String, Int) {
        let trimmed = String(string.drop(while: \.isWhitespace))
        return (trimmed, string.count - trimmed.count)
    }

    private func trimmingTail(_ string: String) -> String {
        var string = string
        while let last = string.last, last.isWhitespace {
            string.removeLast()
        }
        return string
    }
}
