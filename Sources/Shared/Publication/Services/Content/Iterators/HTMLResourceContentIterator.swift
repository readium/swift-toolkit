//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import SwiftSoup

/// Iterates an HTML `resource`, starting from the given `locator`.
///
/// If you want to start mid-resource, the `locator` must contain a
/// `cssSelector` key in its `Locator.Locations` object.
///
/// If you want to start from the end of the resource, the `locator` must have
/// a `progression` of 1.0.
///
/// Locators will contain a `before` context of up to `beforeMaxLength`
/// characters.
public class HTMLResourceContentIterator: ContentIterator {
    /// Factory for an `HTMLResourceContentIterator`.
    public class Factory: ResourceContentIteratorFactory {
        public init() {}

        public func make(
            publication: Publication,
            readingOrderIndex: Int,
            resource: Resource,
            locator: Locator
        ) -> ContentIterator? {
            guard locator.mediaType.isHTML else {
                return nil
            }

            return HTMLResourceContentIterator(
                resource: resource,
                totalProgressionRange: {
                    let positions = await publication.positionsByReadingOrder().getOrNil() ?? []
                    return positions.getOrNil(readingOrderIndex)?
                        .first?.locations.totalProgression
                        .map { start in
                            let end = positions.getOrNil(readingOrderIndex + 1)?
                                .first?.locations.totalProgression
                                ?? 1.0

                            return start ... end
                        }
                },
                locator: locator
            )
        }
    }

    private let resource: Resource
    private let locator: Locator
    private let beforeMaxLength: Int = 50
    private let fetchTotalProgressionRange: () async -> ClosedRange<Double>?

    public init(
        resource: Resource,
        totalProgressionRange: @escaping () async -> ClosedRange<Double>?,
        locator: Locator
    ) {
        self.resource = resource
        self.locator = locator
        fetchTotalProgressionRange = totalProgressionRange
    }

    public func previous() async throws -> ContentElement? {
        let elements = try await elements()
        let index = (currentIndex ?? elements.startIndex) - 1

        guard let content = elements.elements.getOrNil(index) else {
            return nil
        }

        currentIndex = index
        return content
    }

    public func next() async throws -> ContentElement? {
        let elements = try await elements()
        let index = (currentIndex ?? (elements.startIndex - 1)) + 1

        guard let content = elements.elements.getOrNil(index) else {
            return nil
        }

        currentIndex = index
        return content
    }

    private var currentIndex: Int?

    private func elements() async throws -> ParsedElements {
        try await elementsTask.value.get()
    }

    private lazy var elementsTask = Task {
        let range = await fetchTotalProgressionRange()
        return await resource
            .read()
            .asString()
            .eraseToAnyError()
            .tryMap { try SwiftSoup.parse($0) }
            .tryMap { try parse(document: $0, locator: locator, beforeMaxLength: beforeMaxLength) }
            .asyncMap { await adjustProgressions(of: $0, totalProgressionRange: range) }
    }

    private func parse(document: Document, locator: Locator, beforeMaxLength: Int) throws -> ParsedElements {
        let parser = try ContentParser(
            baseLocator: locator,
            startElement: locator.locations.cssSelector
                .flatMap {
                    // The JS third-party library used to generate the CSS
                    // Selector sometimes adds `:root >`, which doesn't work
                    // with SwiftSoup.
                    try document.select($0.removingPrefix(":root > ")).first()
                },
            beforeMaxLength: beforeMaxLength
        )

        try (document.body() ?? document).traverse(parser)

        return parser.result
    }

    private func adjustProgressions(of elements: ParsedElements, totalProgressionRange: ClosedRange<Double>?) async -> ParsedElements {
        let count = Double(elements.elements.count)
        guard count > 0 else {
            return elements
        }

        var elements = elements
        elements.elements = await elements.elements.enumerated().asyncMap { index, element in
            let progression = Double(index) / count
            return element.copy(
                progression: progression,
                totalProgression: totalProgressionRange.map { range in
                    range.lowerBound + progression * (range.upperBound - range.lowerBound)
                }
            )
        }

        // Update the `startIndex` if a particular progression was requested.
        if
            elements.startIndex == 0,
            locator.locations.cssSelector == nil,
            let progression = locator.locations.progression,
            progression > 0, progression < 1
        {
            elements.startIndex = elements.elements.lastIndex { element in
                let elementProgression = element.locator.locations.progression ?? 0
                return elementProgression < progression
            } ?? 0
        }

        return elements
    }

    /// Holds the result of parsing the HTML resource into a list of
    /// `ContentElement`.
    ///
    /// The `startIndex` will be calculated from the element matched by the
    /// base `locator`, if possible. Defaults to 0.
    private struct ParsedElements {
        var elements: [ContentElement] = []
        var startIndex: Int = 0
    }

    private class ContentParser: NodeVisitor {
        private let baseLocator: Locator
        private let baseHREF: AnyURL?
        private let startElement: Element?
        private let beforeMaxLength: Int

        init(baseLocator: Locator, startElement: Element?, beforeMaxLength: Int) {
            self.baseLocator = baseLocator
            baseHREF = baseLocator.href
            self.startElement = startElement
            self.beforeMaxLength = beforeMaxLength
        }

        var result: ParsedElements {
            ParsedElements(
                elements: elements,
                startIndex: (baseLocator.locations.progression == 1.0)
                    ? elements.count - 1
                    : startIndex
            )
        }

        private var elements: [ContentElement] = []
        private var startIndex = 0

        /// Segments accumulated for the current element.
        private var segmentsAcc: [TextContentElement.Segment] = []

        /// Text since the beginning of the current segment, after coalescing
        /// whitespaces.
        private var textAcc = StringBuilder()

        /// Text content since the beginning of the resource, including
        /// whitespaces.
        private var wholeRawTextAcc: String?

        /// Text content since the beginning of the current element, including
        /// whitespaces.
        private var elementRawTextAcc = ""

        /// Text content since the beginning of the current segment, including
        /// whitespaces.
        private var rawTextAcc = ""

        /// Language of the current segment.
        private var currentLanguage: Language?

        /// LIFO stack of the current element's block ancestors.
        private var breadcrumbs: [ParentElement] = []

        private struct ParentElement {
            let element: Element
            let cssSelector: String?
        }

        private var selectorGenerator = CSSSelectorGenerator()

        /// Stack of ancestor elements whose subtrees should be skipped during
        /// content extraction (e.g. audio/video whose children are fallback content).
        private var skippedAncestors: [Element] = []

        private var isInsideSkippedElement: Bool {
            !skippedAncestors.isEmpty
        }

        func head(_ node: Node, _ depth: Int) throws {
            if let node = node as? Element {
                let parent = ParentElement(element: node, cssSelector: selectorGenerator.cssSelector(for: node))
                if node.isBlock() {
                    flushText()
                    if !isInsideSkippedElement {
                        breadcrumbs.append(parent)
                    }
                }

                let tag = node.tagNameNormal()

                lazy var elementLocator: Locator = baseLocator.copy(
                    locations: {
                        if let cssSelector = parent.cssSelector {
                            $0.otherLocations["cssSelector"] = .string(cssSelector)
                        } else {
                            $0.otherLocations.removeValue(forKey: "cssSelector")
                        }
                    }
                )

                if tag == "br" {
                    flushText()

                } else if tag == "img" {
                    flushText()
                    try node.srcRelativeToHREF(baseHREF).map { href in
                        var attributes: [ContentAttribute] = []
                        if let alt = try node.attr("alt").orNilIfBlank() {
                            attributes.append(ContentAttribute(key: .accessibilityLabel, value: alt))
                        }

                        elements.append(ImageContentElement(
                            locator: elementLocator,
                            embeddedLink: Link(href: href.string),
                            caption: nil, // TODO: Get the caption from figcaption
                            attributes: attributes
                        ))
                    }

                } else if tag == "audio" || tag == "video" {
                    flushText()
                    skippedAncestors.append(node)

                    let link: Link? = try {
                        if let href = try node.srcRelativeToHREF(baseHREF) {
                            return Link(href: href.string)
                        } else {
                            let sources = try node.select("source")
                                .compactMap { source in
                                    try source.srcRelativeToHREF(baseHREF).map { href in
                                        try Link(
                                            href: href.string,
                                            mediaType: source.attr("type")
                                                .orNilIfBlank()
                                                .flatMap { MediaType($0) }
                                        )
                                    }
                                }

                            var link = sources.first
                            link?.alternates = Array(sources.dropFirst(1))
                            return link
                        }
                    }()

                    if let link = link {
                        switch tag {
                        case "audio":
                            elements.append(AudioContentElement(locator: elementLocator, embeddedLink: link))
                        case "video":
                            elements.append(VideoContentElement(locator: elementLocator, embeddedLink: link))
                        default:
                            break
                        }
                    }

                } else if node.isBlock() {
                    flushText()
                }
            }
        }

        func tail(_ node: Node, _ depth: Int) throws {
            if let node = node as? TextNode {
                guard !isInsideSkippedElement else { return }

                guard let wholeText = node.getWholeText().orNilIfBlank() else {
                    return
                }

                let language = try node.language().map { Language(code: .bcp47($0)) }
                if currentLanguage != language {
                    flushSegment()
                    currentLanguage = language
                }

                let text = try Parser.unescapeEntities(wholeText, false)
                rawTextAcc += text
                try appendNormalisedText(text)

            } else if let node = node as? Element {
                if skippedAncestors.last === node {
                    skippedAncestors.removeLast()
                }

                if node.isBlock(), !isInsideSkippedElement {
                    assert(breadcrumbs.last?.element == node)
                    flushText()
                    breadcrumbs.removeLast()
                }
            }
        }

        private func appendNormalisedText(_ text: String) throws {
            StringUtil.appendNormalisedWhitespace(textAcc, string: text, stripLeading: lastCharIsWhitespace())
        }

        private func lastCharIsWhitespace() -> Bool {
            guard let lastChar = textAcc.toString().last else {
                return false
            }

            return lastChar == " "
        }

        private func flushText() {
            flushSegment()

            let parent = breadcrumbs.last

            if startIndex == 0, startElement != nil, parent?.element == startElement {
                startIndex = elements.count
            }

            guard !segmentsAcc.isEmpty else {
                return
            }

            // Trim the end of the last segment's text to get a cleaner output
            // for the TextContentElement. Only whitespaces between the
            // segments are meaningful.
            if var segment = segmentsAcc.last {
                segment.text = segment.text.trimingTrailingWhitespacesAndNewlines()
                segmentsAcc[segmentsAcc.count - 1] = segment
            }

            elements.append(
                TextContentElement(
                    locator: baseLocator.copy(
                        locations: {
                            if let cssSelector = parent?.cssSelector {
                                $0.otherLocations["cssSelector"] = .string(cssSelector)
                            } else {
                                $0.otherLocations.removeValue(forKey: "cssSelector")
                            }
                        },
                        text: {
                            $0 = Locator.Text.trimming(
                                text: self.elementRawTextAcc,
                                before: self.segmentsAcc.first?.locator.text.before
                            )
                        }
                    ),
                    role: .body,
                    segments: segmentsAcc
                )
            )
            elementRawTextAcc = ""
            segmentsAcc.removeAll()
        }

        private func flushSegment() {
            var text = textAcc.toString()
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedText.isEmpty {
                if segmentsAcc.isEmpty {
                    text = text.trimmingLeadingWhitespacesAndNewlines()

                    let whitespaceSuffix = text.last
                        .takeIf { $0.isWhitespace }
                        .map { String($0) }
                        ?? ""

                    text = trimmedText + whitespaceSuffix
                }

                let parent = breadcrumbs.last

                var attributes: [ContentAttribute] = []
                if let lang = currentLanguage {
                    attributes.append(ContentAttribute(key: .language, value: lang))
                }

                segmentsAcc.append(TextContentElement.Segment(
                    locator: baseLocator.copy(
                        locations: {
                            if let cssSelector = parent?.cssSelector {
                                $0.otherLocations["cssSelector"] = .string(cssSelector)
                            } else {
                                $0.otherLocations.removeValue(forKey: "cssSelector")
                            }
                        },
                        text: { [self] in
                            $0 = Locator.Text.trimming(
                                text: rawTextAcc,
                                before: (wholeRawTextAcc?.suffix(beforeMaxLength)).map { String($0) }
                            )
                        }
                    ),
                    text: text,
                    attributes: attributes
                ))
            }

            if rawTextAcc != "" {
                wholeRawTextAcc = (wholeRawTextAcc ?? "") + rawTextAcc
                elementRawTextAcc += rawTextAcc
            }
            rawTextAcc = ""
            textAcc.clear()
        }
    }
}

/// Builds CSS selectors for SwiftSoup `Element` nodes, equivalent to
/// SwiftSoup's `cssSelector()` but in O(N) total time by caching parent
/// selectors and per-parent sibling counts.
private struct CSSSelectorGenerator {
    /// Cache of fully-built CSS selectors keyed by SwiftSoup element identity.
    private var selectorCache: [ObjectIdentifier: String?] = [:]

    /// Per-parent count of children grouped by tag name, used to decide
    /// whether `:nth-child(N)` disambiguation is needed.
    private var tagCountCache: [ObjectIdentifier: [String: Int]] = [:]

    /// 1-based child index of each element within its parent, populated
    /// alongside `tagCountCache`.
    private var elementIndexCache: [ObjectIdentifier: Int] = [:]

    /// Returns a unique CSS selector for `element`, or `nil` if one cannot be
    /// constructed (e.g. a detached node with no id and no parent).
    mutating func cssSelector(for element: Element) -> String? {
        let key = ObjectIdentifier(element)
        if let cached = selectorCache[key] {
            return cached
        }

        let result: String?
        let elementId = element.id()

        if !elementId.isEmpty {
            result = "#" + cssEscapeIdentifier(elementId)
        } else if let parent = element.parent() {
            let tagName = element.tagName().replacingOccurrences(of: ":", with: "|")
            let segment = selectorSegment(tagName: tagName, element: element, parent: parent)
            if parent is Document {
                result = segment
            } else if let parentSelector = cssSelector(for: parent) {
                result = "\(parentSelector) > \(segment)"
            } else {
                result = segment
            }
        } else {
            result = nil
        }

        selectorCache.updateValue(result, forKey: key)
        return result
    }

    /// Builds the selector segment for a single element (e.g. `p`,
    /// `div.center`, `p:nth-child(3)`). Appends `:nth-child(N)` when more than
    /// one sibling shares the same tag name, so positional uniqueness is always
    /// guaranteed.
    private mutating func selectorSegment(tagName: String, element: Element, parent: Element) -> String {
        var segment = tagName

        if let classSet = try? element.classNames(), !classSet.isEmpty {
            segment += "." + classSet.sorted().map(cssEscapeIdentifier).joined(separator: ".")
        }

        let parentId = ObjectIdentifier(parent)
        if tagCountCache[parentId] == nil {
            var counts: [String: Int] = [:]
            var index = 0
            for child in parent.children() {
                index += 1
                let tag = child.tagName().replacingOccurrences(of: ":", with: "|")
                counts[tag, default: 0] += 1
                elementIndexCache[ObjectIdentifier(child)] = index
            }
            tagCountCache[parentId] = counts
        }

        if
            (tagCountCache[parentId]?[tagName] ?? 0) > 1,
            let index = elementIndexCache[ObjectIdentifier(element)]
        {
            segment += ":nth-child(\(index))"
        }

        return segment
    }

    /// Escapes a CSS identifier, matching SwiftSoup's `Element.cssEscapeIdentifier`.
    private func cssEscapeIdentifier(_ identifier: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(identifier.count)
        for character in identifier {
            if character.isLetter || character.isNumber || character == "-" || character == "_" {
                escaped.append(character)
            } else {
                escaped.append("\\")
                escaped.append(character)
            }
        }
        return escaped
    }
}

private extension Node {
    func srcRelativeToHREF(_ baseHREF: AnyURL?) throws -> AnyURL? {
        try attr("src").orNilIfBlank()
            .flatMap { AnyURL(string: $0) }
            .flatMap {
                baseHREF?.resolve($0) ?? $0
            }
    }

    func language() throws -> String? {
        try attr("xml:lang").orNilIfBlank()
            ?? attr("lang").orNilIfBlank()
            ?? parent()?.language()
    }
}

private extension ContentElement {
    func copy(progression: Double?, totalProgression: Double?) -> ContentElement {
        func update(_ locator: Locator) -> Locator {
            locator.copy(locations: {
                $0.progression = progression
                $0.totalProgression = totalProgression
            })
        }

        switch self {
        case var e as TextContentElement:
            e.locator = update(e.locator)
            e.segments = e.segments.map { segment in
                var segment = segment
                segment.locator = update(segment.locator)
                return segment
            }
            return e

        case var e as AudioContentElement:
            e.locator = update(e.locator)
            return e

        case var e as ImageContentElement:
            e.locator = update(e.locator)
            return e

        case var e as VideoContentElement:
            e.locator = update(e.locator)
            return e

        default:
            return self
        }
    }
}

private extension Locator.Text {
    static func trimming(text: String, before: String?) -> Locator.Text {
        let leadingWhitespaceIdx = text.firstIndex { !$0.isWhitespace && !$0.isNewline } ?? text.startIndex
        let leadingWhitespace = String(text[..<leadingWhitespaceIdx])

        let trailingWhitespaceIdx = text.lastIndex { !$0.isWhitespace && !$0.isNewline }
            .map { text.index(after: $0) }
            ?? text.endIndex
        let trailingWhitespace = String(text[trailingWhitespaceIdx...])

        return Locator.Text(
            after: trailingWhitespace.orNilIfBlank(),
            before: ((before ?? "") + leadingWhitespace).orNilIfBlank(),
            highlight: String(text[leadingWhitespaceIdx ..< trailingWhitespaceIdx])
        )
    }
}

private extension String {
    func trimmingLeadingWhitespacesAndNewlines() -> String {
        firstIndex { !$0.isWhitespace && !$0.isNewline }
            .map { index in String(self[index...]) }
            ?? self
    }

    func trimingTrailingWhitespacesAndNewlines() -> String {
        lastIndex { !$0.isWhitespace && !$0.isNewline }
            .map { index in String(self[...index]) }
            ?? self
    }
}
