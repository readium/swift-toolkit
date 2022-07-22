//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftSoup

public class HTMLResourceContentIterator : ContentIterator {

    // FIXME: Custom skipped elements
    public static func makeFactory() -> ResourceContentIteratorFactory {
        { resource, locator in
            HTMLResourceContentIterator(resource: resource, locator: locator)
        }
    }

    private var content: Result<[Content], Error>
    private var currentIndex: Int?
    private var startingIndex: Int

    public init(resource: Resource, locator: Locator) {
        let result = resource
            .readAsString()
            .eraseToAnyError()
            .tryMap { try SwiftSoup.parse($0) }
            .tryMap { document -> (content: [Content], startingIndex: Int) in
                try ContentParser.parse(document: document, locator: locator)
            }

        content = result.map { $0.content }
        startingIndex = result.map { $0.startingIndex }.get(or: 0)
    }

    public func close() {}

    public func previous() throws -> Content? {
        try next(by: -1)
    }

    public func next() throws -> Content? {
        try next(by: +1)
    }

    private func next(by delta: Int) throws -> Content? {
        let content = try content.get()
        let index = index(by: delta)
        guard content.indices.contains(index) else {
            return nil
        }
        currentIndex = index
        return content[index]
    }

    private func index(by delta: Int) -> Int {
        if let i = currentIndex {
            return i + delta
        } else {
            return startingIndex
        }
    }

    private class ContentParser: NodeVisitor {
        
        static func parse(document: Document, locator: Locator) throws -> (content: [Content], startingIndex: Int) {
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
            
            var result = (
                content: parser.content,
                startingIndex: parser.startIndex
            )
            
            if locator.locations.progression == 1.0 {
                result.startingIndex = result.content.count - 1
            }
            
            return result
        }

        private let baseLocator: Locator
        private let startElement: Element?

        private(set) var content: [Content] = []
        private(set) var startIndex = 0
        private var currentElement: Element?
        private var spansAcc: [Content.TextSpan] = []
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

                let cssSelector = try elem.cssSelector()
                let tag = elem.tagNameNormal()

                if tag == "br" {
                    flushText()
                } else if tag == "img" {
                    flushText()

                    if let href = try elem.attr("src")
                        .takeUnlessEmpty()
                        .map({ HREF($0, relativeTo: baseLocator.href).string }) {
                        content.append(Content(
                            locator: baseLocator.copy(
                                locations: {
                                    $0 = Locator.Locations(
                                        otherLocations: ["cssSelector": cssSelector]
                                    )
                                }
                            ),
                            data: .image(
                                target: Link(href: href),
                                description: try elem.attr("alt").takeUnlessEmpty()
                            )
                        ))
                    }

                } else if elem.isBlock() {
                    spansAcc.removeAll()
                    textAcc.clear()
                    rawTextAcc = ""
                    currentCSSSelector = cssSelector
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
                    flushSpan()
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
            flushSpan()
            guard !spansAcc.isEmpty else {
                return
            }

            if startElement != nil && currentElement == startElement {
                startIndex = content.count
            }
            content.append(Content(
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
                data: .text(spans: spansAcc, style: .body)
            ))
            elementRawTextAcc = ""
            spansAcc.removeAll()
        }

        private func flushSpan() {
            var text = textAcc.toString()
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                if spansAcc.isEmpty {
                    let whitespaceSuffix = text.last
                        .takeIf { $0.isWhitespace || $0.isNewline }
                        .map { String($0) }
                        ?? ""

                    text = trimmedText + whitespaceSuffix
                }

                spansAcc.append(Content.TextSpan(
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
                    language: currentLanguage,
                    text: text
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
