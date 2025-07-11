//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A list of EPUB resources to be displayed together on the screen, as one-page
/// or two-pages spread.
struct EPUBSpread: Loggable {
    /// Indicates whether two pages are displayed side by side.
    var spread: Bool

    /// Indices for the resources displayed in the spread, in reading order.
    ///
    /// Note: it's possible to have less links than the amount of `pageCount`
    /// available, because a single page might be displayed in a two-page spread
    /// (eg. with Properties.Page center, left or right).
    var readingOrderIndices: ReadingOrderIndices

    /// Spread reading progression direction.
    var readingProgression: ReadingProgression

    init(spread: Bool, readingOrderIndices: ReadingOrderIndices, readingProgression: ReadingProgression) {
        precondition(!readingOrderIndices.isEmpty, "A spread must have at least one page")
        precondition(spread || readingOrderIndices.count == 1, "A one-page spread must have only one page")
        precondition(!spread || 1 ... 2 ~= readingOrderIndices.count, "A two-pages spread must have one or two pages max")
        self.spread = spread
        self.readingOrderIndices = readingOrderIndices
        self.readingProgression = readingProgression
    }

    /// Returns the left-most reading order index in the spread.
    var left: ReadingOrder.Index {
        switch readingProgression {
        case .ltr:
            readingOrderIndices.lowerBound
        case .rtl:
            readingOrderIndices.upperBound
        }
    }

    /// Returns the right-most reading order index in the spread.
    var right: ReadingOrder.Index {
        switch readingProgression {
        case .ltr:
            readingOrderIndices.upperBound
        case .rtl:
            readingOrderIndices.lowerBound
        }
    }

    /// Returns the leading reading order index in the reading progression.
    var leading: ReadingOrder.Index {
        readingOrderIndices.lowerBound
    }

    /// Returns whether the spread contains the resource at the given reading
    /// order index
    func contains(index: ReadingOrder.Index) -> Bool {
        readingOrderIndices.contains(index)
    }

    /// Return the number of positions contained in the spread.
    func positionCount(in readingOrder: ReadingOrder, positionsByReadingOrder: [[Locator]]) -> Int {
        readingOrderIndices
            .map { index in
                positionsByReadingOrder[index].count
            }
            .reduce(0, +)
    }

    /// Returns a JSON representation of the links in the spread.
    /// The JSON is an array of link objects in reading progression order.
    /// Each link object contains:
    ///   - link: Link object of the resource in the Publication
    ///   - url: Full URL to the resource.
    ///   - page [left|center|right]: (optional) Page position of the linked resource in the spread.
    func json(forBaseURL baseURL: HTTPURL, readingOrder: ReadingOrder) -> [[String: Any]] {
        func makeLinkJSON(_ index: ReadingOrder.Index, page: Properties.Page? = nil) -> [String: Any]? {
            guard let link = readingOrder.getOrNil(index) else {
                return nil
            }

            let page = page ?? link.properties.page ?? readingProgression.startingPage
            return [
                "index": index,
                "link": link.json,
                "url": link.url(relativeTo: baseURL).string,
                "page": page.rawValue,
            ]
        }

        var json: [[String: Any]?] = []

        if readingOrderIndices.count == 1 {
            json.append(makeLinkJSON(leading))
        } else {
            json.append(makeLinkJSON(left, page: .left))
            json.append(makeLinkJSON(right, page: .right))
        }

        return json.compactMap { $0 }
    }

    func jsonString(forBaseURL baseURL: HTTPURL, readingOrder: ReadingOrder) -> String {
        serializeJSONString(json(forBaseURL: baseURL, readingOrder: readingOrder)) ?? "[]"
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
        readingOrder.enumerated().map { index, _ in
            EPUBSpread(
                spread: false,
                readingOrderIndices: index ... index,
                readingProgression: readingProgression
            )
        }
    }

    /// Builds a list of two-page spreads for the given Publication.
    private static func makeTwoPagesSpreads(
        for publication: Publication,
        readingOrder: [Link],
        readingProgression: ReadingProgression
    ) -> [EPUBSpread] {
        var spreads: [EPUBSpread] = []

        var index = 0
        while index < readingOrder.count {
            let first = readingOrder[index]

            var spread = EPUBSpread(
                spread: true,
                readingOrderIndices: index ... index,
                readingProgression: readingProgression
            )

            let nextIndex = index + 1
            // To be displayed together, two pages must be part of a fixed
            // layout publication and have consecutive position hints
            // (Properties.Page).
            if
                let second = readingOrder.getOrNil(nextIndex),
                publication.metadata.layout == .fixed,
                publication.areConsecutive(first, second, index: index)
            {
                spread.readingOrderIndices = index ... nextIndex
                index += 1 // Skips the consumed "second" page
            }

            spreads.append(spread)
            index += 1
        }

        return spreads
    }
}

extension Array where Element == EPUBSpread {
    /// Returns the index of the first spread containing a resource with the given `href`.
    func firstIndexWithReadingOrderIndex(_ index: ReadingOrder.Index) -> Int? {
        firstIndex { spread in
            spread.contains(index: index)
        }
    }
}

private extension Publication {
    /// Two resources are consecutive if their position hint (Properties.Page)
    /// are paired according to the reading progression.
    func areConsecutive(_ first: Link, _ second: Link, index: Int) -> Bool {
        guard index > 0 || first.properties.page != nil else {
            return false
        }

        // Here we use the default publication reading progression instead
        // of the custom one provided, otherwise the page position hints
        // might be wrong, and we could end up with only one-page spreads.
        switch metadata.readingProgression {
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
}
