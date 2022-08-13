//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftSoup

// FIXME: Custom skipped elements

/// Iterates an HTML `resource`, starting from the given `locator`.
///
/// If you want to start mid-resource, the `locator` must contain a `cssSelector` key in its
/// `Locator.Locations` object.
///
/// If you want to start from the end of the resource, the `locator` must have a `progression` of 1.0.
public class HTMLResourceContentIterator: ContentIterator {

    /// Creates a new factory for `HTMLResourceContentIterator`.
    public static func makeFactory() -> ResourceContentIteratorFactory {
        { resource, locator in
            guard resource.link.mediaType.isHTML else {
                return nil
            }
            return HTMLResourceContentIterator(resource: resource, locator: locator)
        }
    }

    private let resource: Resource
    private let locator: Locator

    public init(resource: Resource, locator: Locator) {
        self.resource = resource
        self.locator = locator
    }

    public func previous() throws -> ContentElement? {
        try next(by: -1)
    }

    public func next() throws -> ContentElement? {
        try next(by: +1)
    }

    private func next(by delta: Int) throws -> ContentElement? {
        let elements = try self.elements.get()
        let index = currentIndex.map { $0 + delta }
            ?? elements.startIndex

        guard elements.elements.indices.contains(index) else {
            return nil
        }

        currentIndex = index
        return elements.elements[index]
    }

    private var currentIndex: Int?

    private lazy var elements: Result<ParsedElements, Error> = parseElements()

    private func parseElements() -> Result<ParsedElements, Error> {
        let result = resource
            .readAsString()
            .eraseToAnyError()
            .tryMap { try SwiftSoup.parse($0) }
            .tryMap { try ContentParser.parse(document: $0, locator: locator) }
        resource.close()
        return result
    }


    /// Holds the result of parsing the HTML resource into a list of `ContentElement`.
    ///
    /// The `startIndex` will be calculated from the element matched by the base `locator`, if possible. Defaults to
    /// 0.
    private typealias ParsedElements = (elements: [ContentElement], startIndex: Int)

    private class ContentParser: NodeVisitor {
        
        static func parse(document: Document, locator: Locator) throws -> ParsedElements {
            let parser = ContentParser(
                baseLocator: locator,
                startElement: try locator.locations.cssSelector
                    .flatMap {
                        // The JS third-party library used to generate the CSS Selector sometimes adds
                        // :root >, which doesn't work with JSoup.
                        try document.select($0.removingPrefix(":root > ")).first()
                    }
            )

            try document.traverse(parser)

            return ParsedElements(
                elements: parser.elements,
                startIndex: (locator.locations.progression == 1.0)
                    ? parser.elements.count - 1
                    : parser.startIndex
            )
        }

        private let baseLocator: Locator
        private let startElement: Element?

        private var elements: [ContentElement] = []
        private var startIndex = 0
        private var currentElement: Element?

        private var segmentsAcc: [TextContentElement.Segment] = []
        private var textAcc = StringBuilder()
        private var wholeRawTextAcc: String = ""
        private var elementRawTextAcc: String = ""
        private var rawTextAcc: String = ""
        private var currentLanguage: Language?
        private var currentCSSSelector: String?
        private var ignoredNode: Node?

        private init(baseLocator: Locator, startElement: Element?) {
            self.baseLocator = baseLocator
            self.startElement = startElement
        }

        public func head(_ node: Node, _ depth: Int) throws {
            guard ignoredNode == nil else {
                return
            }
            guard !node.isHidden else {
                ignoredNode = node
                return
            }

            if let elem = node as? Element {
                currentElement = elem

                let tag = elem.tagNameNormal()

                if tag == "br" {
                    flushText()
                } else if tag == "img" {
                    flushText()

                    if
                        let href = try elem.attr("src")
                            .takeUnlessEmpty()
                            .map({ HREF($0, relativeTo: baseLocator.href).string })
                    {
                        var attributes: [ContentAttribute] = []
                        if let alt = try elem.attr("alt").takeUnlessEmpty() {
                            attributes.append(ContentAttribute(key: .accessibilityLabel, value: alt))
                        }

                        elements.append(ImageContentElement(
                            locator: baseLocator.copy(
                                locations: {
                                    $0 = Locator.Locations(
                                        otherLocations: ["cssSelector": try? elem.cssSelector()]
                                    )
                                }
                            ),
                            embeddedLink: Link(href: href),
                            caption: nil, // FIXME: Get the caption from figcaption
                            attributes: attributes
                        ))
                    }

                } else if elem.isBlock() {
                    segmentsAcc.removeAll()
                    textAcc.clear()
                    rawTextAcc = ""
                    currentCSSSelector = try elem.cssSelector()
                }
            }
        }

        func tail(_ node: Node, _ depth: Int) throws {
            if ignoredNode == node {
                ignoredNode = nil
            }

            if let node = node as? TextNode {
                let language = try node.language().map { Language(code: .bcp47($0)) }
                if (currentLanguage != language) {
                    flushSegment()
                    currentLanguage = language
                }

                rawTextAcc += try Parser.unescapeEntities(node.getWholeText(), false)
                try appendNormalisedText(of: node)

            } else if let node = node as? Element {
                if node.isBlock() {
                    flushText()
                }
            }
        }

        private func appendNormalisedText(of textNode: TextNode) throws {
            let text = try Parser.unescapeEntities(textNode.getWholeText(), false)
            return StringUtil.appendNormalisedWhitespace(textAcc, string: text, stripLeading: lastCharIsWhitespace())
        }

        private func lastCharIsWhitespace() -> Bool {
            textAcc.toString().last?.isWhitespace ?? false
        }

        private func flushText() {
            flushSegment()
            guard !segmentsAcc.isEmpty else {
                return
            }

            if startElement != nil && currentElement == startElement {
                startIndex = elements.count
            }
            elements.append(TextContentElement(
                locator: baseLocator.copy(
                    locations: { [self] in
                        $0 = Locator.Locations(
                            otherLocations: [
                                "cssSelector": currentCSSSelector as Any
                            ]
                        )
                    },
                    text: { [self] in
                        $0 = Locator.Text(
                            highlight: elementRawTextAcc
                        )
                    }
                ),
                role: .body,
                segments: segmentsAcc
            ))
            elementRawTextAcc = ""
            segmentsAcc.removeAll()
        }

        private func flushSegment() {
            var text = textAcc.toString()
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
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
                            $0 = Locator.Locations(
                                otherLocations: [
                                    "cssSelector": currentCSSSelector as Any
                                ]
                            )
                        },
                        text: { [self] in
                            $0 = Locator.Text(
                                before: String(wholeRawTextAcc.suffix(50)),
                                highlight: rawTextAcc // FIXME: custom length
                            )
                        }
                    ),
                    text: text,
                    attributes: attributes
                ))
            }

            wholeRawTextAcc += rawTextAcc
            elementRawTextAcc += rawTextAcc
            rawTextAcc = ""
            textAcc.clear()
        }
    }
}

private extension Node {
    // FIXME: Setup ignore conditions
    var isHidden: Bool { false }

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
