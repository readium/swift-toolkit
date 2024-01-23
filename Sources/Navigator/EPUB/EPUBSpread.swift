//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// A list of EPUB resources to be displayed together on the screen, as one-page or two-pages spread.
struct EPUBSpread: Loggable {
    /// Indicates whether two pages are displayed side by side.
    let spread: Bool

    /// Links for the resources displayed in the spread, in reading order.
    /// Note: it's possible to have less links than the amount of `pageCount` available, because a single page might be displayed in a two-page spread (eg. with Properties.Page center, left or right)
    let links: [Link]

    /// Spread reading progression direction.
    let readingProgression: ReadingProgression

    /// Rendition layout of the links in the spread.
    let layout: EPUBLayout

    init(spread: Bool, links: [Link], readingProgression: ReadingProgression, layout: EPUBLayout) {
        precondition(!links.isEmpty, "A spread must have at least one page")
        precondition(spread || links.count == 1, "A one-page spread must have only one page")
        precondition(!spread || 1 ... 2 ~= links.count, "A two-pages spread must have one or two pages max")
        self.spread = spread
        self.links = links
        self.readingProgression = readingProgression
        self.layout = layout
    }

    /// Links for the resources in the spread, from left to right.
    var linksLTR: [Link] {
        switch readingProgression {
        case .ltr:
            return links
        case .rtl:
            return links.reversed()
        }
    }

    /// Returns the left-most resource link in the spread.
    var left: Link {
        linksLTR.first!
    }

    /// Returns the right-most resource link in the spread.
    var right: Link {
        linksLTR.last!
    }

    /// Returns the leading resource link in the reading progression.
    var leading: Link {
        links.first!
    }

    /// Returns whether the spread contains a resource with the given href.
    func contains(href: String) -> Bool {
        links.first(withHREF: href) != nil
    }

    /// Return the number of positions (as in `Publication.positionList`) contained in the spread.
    func positionCount(in readingOrder: [Link], positionsByReadingOrder: [[Locator]]) -> Int {
        links
            .map {
                if let index = readingOrder.firstIndex(withHREF: $0.href) {
                    return positionsByReadingOrder[index].count
                } else {
                    return 0
                }
            }
            .reduce(0, +)
    }

    /// Returns a JSON representation of the links in the spread.
    /// The JSON is an array of link objects in reading progression order.
    /// Each link object contains:
    ///   - link: Link object of the resource in the Publication
    ///   - url: Full URL to the resource.
    ///   - page [left|center|right]: (optional) Page position of the linked resource in the spread.
    func json(forBaseURL baseURL: URL) -> [[String: Any]] {
        func makeLinkJSON(_ link: Link, page: Presentation.Page? = nil) -> [String: Any]? {
            guard let url = link.url(relativeTo: baseURL) else {
                log(.error, "Can't get URL for link \(link.href)")
                return nil
            }
            let page = page ?? link.properties.page ?? readingProgression.leadingPage
            return [
                "link": link.json,
                "url": url.absoluteString,
                "page": page.rawValue,
            ]
        }

        var json: [[String: Any]?] = []

        if links.count == 1 {
            json.append(makeLinkJSON(leading))
        } else {
            json.append(makeLinkJSON(left, page: .left))
            json.append(makeLinkJSON(right, page: .right))
        }

        return json.compactMap { $0 }
    }

    func jsonString(forBaseURL baseURL: URL) -> String {
        serializeJSONString(json(forBaseURL: baseURL)) ?? "[]"
    }

    /// Builds a list of spreads for the given Publication.
    ///
    /// - Parameters:
    ///   - publication: The Publication to build the spreads for.
    ///   - readingProgression: Reading progression direction used to layout the pages.
    ///   - spread: Indicates whether two pages are displayed side-by-side.
    static func makeSpreads(
        for publication: Publication,
        readingOrder: [Link],
        readingProgression: ReadingProgression,
        spread: Bool
    ) -> [EPUBSpread] {
        spread
            ? makeTwoPagesSpreads(for: publication, readingOrder: readingOrder, readingProgression: readingProgression)
            : makeOnePageSpreads(for: publication, readingOrder: readingOrder, readingProgression: readingProgression)
    }

    /// Builds a list of one-page spreads for the given Publication.
    private static func makeOnePageSpreads(
        for publication: Publication,
        readingOrder: [Link],
        readingProgression: ReadingProgression
    ) -> [EPUBSpread] {
        readingOrder.map {
            EPUBSpread(
                spread: false,
                links: [$0],
                readingProgression: readingProgression,
                layout: publication.metadata.presentation.layout(of: $0)
            )
        }
    }

    /// Builds a list of two-page spreads for the given Publication.
    private static func makeTwoPagesSpreads(
        for publication: Publication,
        readingOrder: [Link],
        readingProgression: ReadingProgression
    ) -> [EPUBSpread] {
        /// Builds two-pages spreads from a list of links and a spread accumulator.
        func makeSpreads(for links: [Link], in spreads: [EPUBSpread] = []) -> [EPUBSpread] {
            var links = links
            var spreads = spreads
            guard !links.isEmpty else {
                return spreads
            }

            let first = links.removeFirst()
            let layout = publication.metadata.presentation.layout(of: first)
            // To be displayed together, the two pages must have a fixed layout, and have consecutive position hints (Properties.Page).
            if let second = links.first,
               layout == .fixed,
               layout == publication.metadata.presentation.layout(of: second),
               areConsecutive(first, second)
            {
                spreads.append(EPUBSpread(
                    spread: true,
                    links: [first, second],
                    readingProgression: readingProgression, layout: layout
                ))
                links.removeFirst() // Removes the consumed "second" page
            } else {
                spreads.append(EPUBSpread(
                    spread: true,
                    links: [first],
                    readingProgression: readingProgression, layout: layout
                ))
            }

            return makeSpreads(for: links, in: spreads)
        }

        /// Two resources are consecutive if their position hint (Properties.Page) are paired according to the reading progression.
        func areConsecutive(_ first: Link, _ second: Link) -> Bool {
            // Here we use the default publication reading progression instead of the custom one provided, otherwise the page position hints might be wrong, and we could end up with only one-page spreads.
            switch publication.metadata.effectiveReadingProgression {
            case .ltr, .ttb, .auto:
                let firstPosition = first.properties.page ?? .left
                let secondPosition = second.properties.page ?? .right
                return firstPosition == .left && secondPosition == .right
            case .rtl, .btt:
                let firstPosition = first.properties.page ?? .right
                let secondPosition = second.properties.page ?? .left
                return firstPosition == .right && secondPosition == .left
            }
        }

        return makeSpreads(for: readingOrder)
    }
}

extension Array where Element == EPUBSpread {
    /// Returns the index of the first spread containing a resource with the given `href`.
    func firstIndex(withHref href: String) -> Int? {
        firstIndex { spread in
            spread.links.contains { $0.href == href }
        }
    }
}
