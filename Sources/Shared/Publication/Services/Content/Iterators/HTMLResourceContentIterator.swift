//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftSoup

/// Iterates an HTML `resource`, starting from the given `locator`.
///
/// If you want to start mid-resource, the `locator` must contain a
/// `cssSelector` key in its `Locator.Locations` object.
///
/// If you want to start from the end of the resource, the `locator` must have
/// a `progression` of 1.0.
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
            guard resource.link.mediaType.isHTML else {
                return nil
            }

            let positions = publication.positionsByReadingOrder
            return HTMLResourceContentIterator(
                resource: resource,
                totalProgressionRange: positions.getOrNil(readingOrderIndex)?
                    .first?.locations.totalProgression
                    .map { start in
                        let end = positions.getOrNil(readingOrderIndex + 1)?
                            .first?.locations.totalProgression
                            ?? 1.0

                        return start ... end
                    },
                locator: locator
            )
        }
    }

    private let resource: Resource
    private let totalProgressionRange: ClosedRange<Double>?
    private let locator: Locator
    private let beforeMaxLength: Int = 50

    public init(
        resource: Resource,
        totalProgressionRange: ClosedRange<Double>?,
        locator: Locator
    ) {
        self.resource = resource
        self.totalProgressionRange = totalProgressionRange
        self.locator = locator
    }

    public func previous() throws -> ContentElement? {
        let elements = try elements.get()
        let index = (currentIndex ?? elements.startIndex) - 1

        guard let content = elements.elements.getOrNil(index) else {
            return nil
        }

        currentIndex = index
        return content
    }

    public func next() throws -> ContentElement? {
        let elements = try elements.get()
        let index = (currentIndex ?? (elements.startIndex - 1)) + 1

        guard let content = elements.elements.getOrNil(index) else {
            return nil
        }

        currentIndex = index
        return content
    }

    private var currentIndex: Int?

    private lazy var elements: Result<ParsedElements, Error> = parseElements()

    private func parseElements() -> Result<ParsedElements, Error> {
        let result = resource
            .readAsString()
            .eraseToAnyError()
            .tryMap { try SwiftSoup.parse($0) }
            .tryMap { try ContentParser.parse(document: $0, locator: locator, beforeMaxLength: beforeMaxLength) }
            .map { adjustProgressions(of: $0) }
        resource.close()
        return result
    }

    /// Holds the result of parsing the HTML resource into a list of
    /// `ContentElement`.
    ///
    /// The `startIndex` will be calculated from the element matched by the
    /// base `locator`, if possible. Defaults to 0.
    private struct ParsedElements {
        var elements: [ContentElement]
        var startIndex: Int
    }

    private func adjustProgressions(of elements: ParsedElements) -> ParsedElements {
        let count = Double(elements.elements.count)
        guard count > 0 else {
            return elements
        }

        var elements = elements
        elements.elements = elements.elements.enumerated().map { index, element in
            let progression = Double(index) / count
            return element.copy(
                progression: progression,
                totalProgression: totalProgressionRange.map { range in
                    range.lowerBound + progression * (range.upperBound - range.lowerBound)
                }
            )
        }
        return elements
    }

    private class ContentParser: NodeVisitor {
        static func parse(document: Document, locator: Locator, beforeMaxLength: Int) throws -> ParsedElements {
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

            return ParsedElements(
                elements: parser.elements,
                startIndex: (locator.locations.progression == 1.0)
                    ? parser.elements.count - 1
                    : parser.startIndex
            )
        }

        private init(baseLocator: Locator, startElement: Element?, beforeMaxLength: Int) {
            self.baseLocator = baseLocator
            self.startElement = startElement
            self.beforeMaxLength = beforeMaxLength
        }

        private let baseLocator: Locator
        private let startElement: Element?
        private let beforeMaxLength: Int

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

        /// CSS selector of the current element.
        private var currentCSSSelector: String?

        /// LIFO stack of the current element's block ancestors.
        private var breadcrumbs: [Element] = []

        public func head(_ node: Node, _ depth: Int) throws {
            if let node = node as? Element {
                if node.isBlock() {
                    breadcrumbs.append(node)
                }

                let tag = node.tagNameNormal()

                lazy var elementLocator: Locator = baseLocator.copy(
                    locations: {
                        $0.otherLocations = [
                            "cssSelector": (try? node.cssSelector()) as Any,
                        ]
                    }
                )

                if tag == "br" {
                    flushText()

                } else if tag == "img" {
                    flushText()
                    try node.srcRelativeToHREF(baseLocator.href).map { href in
                        var attributes: [ContentAttribute] = []
                        if let alt = try node.attr("alt").takeUnlessEmpty() {
                            attributes.append(ContentAttribute(key: .accessibilityLabel, value: alt))
                        }

                        elements.append(ImageContentElement(
                            locator: elementLocator,
                            embeddedLink: Link(href: href),
                            caption: nil, // FIXME: Get the caption from figcaption
                            attributes: attributes
                        ))
                    }

                } else if tag == "audio" || tag == "video" {
                    flushText()

                    let link: Link? = try {
                        if let href = try node.srcRelativeToHREF(baseLocator.href) {
                            return Link(href: href)
                        } else {
                            let sources = try node.select("source")
                                .compactMap { source in
                                    try source.srcRelativeToHREF(baseLocator.href).map { href in
                                        try Link(href: href, type: source.attr("type").takeUnlessEmpty())
                                    }
                                }

                            return sources.first?.copy(alternates: Array(sources.dropFirst(1)))
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
                    currentCSSSelector = try node.cssSelector()
                }
            }
        }

        func tail(_ node: Node, _ depth: Int) throws {
            if let node = node as? TextNode {
                let wholeText = node.getWholeText()
                guard !wholeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
                if node.isBlock() {
                    assert(breadcrumbs.last == node)
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

            return lastChar.isWhitespace || lastChar.isNewline
        }

        private func flushText() {
            flushSegment()

            if startIndex == 0, startElement != nil, breadcrumbs.last == startElement {
                startIndex = elements.count
            }

            guard !segmentsAcc.isEmpty else {
                return
            }

            // Trim the end of the last segment's text to get a cleaner output
            // for the TextContentElement. Only whitespaces between the
            // segments are meaningful.
            if var segment = segmentsAcc.last {
                segment.text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                segmentsAcc[segmentsAcc.count - 1] = segment
            }

            elements.append(
                TextContentElement(
                    locator: baseLocator.copy(
                        locations: {
                            if let selector = self.currentCSSSelector {
                                $0.otherLocations["cssSelector"] = selector
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
                    let whitespaceSuffix = text.last
                        .takeIf { $0.isWhitespace || $0.isNewline }
                        .map { String($0) }
                        ?? ""

                    text = trimmedText + whitespaceSuffix
                }

                var attributes: [ContentAttribute] = []
                if let lang = currentLanguage {
                    attributes.append(ContentAttribute(key: .language, value: lang))
                }

                segmentsAcc.append(TextContentElement.Segment(
                    locator: baseLocator.copy(
                        locations: { [self] in
                            $0.otherLocations = [
                                "cssSelector": currentCSSSelector as Any,
                            ]
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

private extension Node {
    func srcRelativeToHREF(_ baseHREF: String) throws -> String? {
        try attr("src").takeUnlessEmpty()
            .map { HREF($0, relativeTo: baseHREF).string }
    }

    func language() throws -> String? {
        try attr("xml:lang").takeUnlessEmpty()
            ?? attr("lang").takeUnlessEmpty()
            ?? parent()?.language()
    }

    func parentElement() -> Element? {
        (parent() as? Element)
            ?? parent()?.parentElement()
    }
}

private extension String {
    func takeUnlessEmpty() -> String? {
        isEmpty ? nil : self
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
            after: trailingWhitespace.takeUnlessEmpty(),
            before: ((before ?? "") + leadingWhitespace).takeUnlessEmpty(),
            highlight: String(text[leadingWhitespaceIdx ..< trailingWhitespaceIdx])
        )
    }
}
