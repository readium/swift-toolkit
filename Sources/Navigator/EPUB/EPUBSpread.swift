//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Common interface for spread types.
protocol EPUBSpreadProtocol {
    /// Returns whether the spread contains the resource at the given reading
    /// order index.
    func contains(index: ReadingOrder.Index) -> Bool

    /// Return the number of positions contained in the spread.
    func positionCount(in readingOrder: ReadingOrder, positionsByReadingOrder: [[Locator]]) -> Int

    /// Returns a JSON representation of the links in the spread.
    ///
    /// The JSON is an array of link objects in reading progression order.
    /// Each link object contains:
    ///   - link: Link object of the resource in the Publication
    ///   - url: Full URL to the resource.
    ///   - page [left|center|right]: (optional) Page position of the linked resource in the spread.
    func json(forBaseURL baseURL: HTTPURL, readingProgression: ReadingProgression) -> [[String: Any]]
}

/// Represents a spread of EPUB resources displayed in the viewport. A spread
/// can contain one or two resources (for FXL).
enum EPUBSpread: EPUBSpreadProtocol {
    /// A spread displaying a single resource.
    case single(EPUBSingleSpread)
    /// A spread displaying two resources side by side (FXL only).
    case double(EPUBDoubleSpread)

    /// Range of reading order indices contained in this spread.
    var readingOrderIndices: ReadingOrderIndices {
        switch self {
        case let .single(spread):
            return spread.resource.index ... spread.resource.index
        case let .double(spread):
            return spread.first.index ... spread.second.index
        }
    }

    /// The leading resource in the reading progression.
    var first: EPUBSpreadResource {
        switch self {
        case let .single(spread):
            return spread.resource
        case let .double(spread):
            return spread.first
        }
    }

    private var spread: EPUBSpreadProtocol {
        switch self {
        case let .single(spread):
            return spread
        case let .double(spread):
            return spread
        }
    }

    func contains(index: ReadingOrder.Index) -> Bool {
        spread.contains(index: index)
    }

    func positionCount(in readingOrder: ReadingOrder, positionsByReadingOrder: [[Locator]]) -> Int {
        spread.positionCount(in: readingOrder, positionsByReadingOrder: positionsByReadingOrder)
    }

    func json(forBaseURL baseURL: HTTPURL, readingProgression: ReadingProgression) -> [[String: Any]] {
        spread.json(forBaseURL: baseURL, readingProgression: readingProgression)
    }

    func jsonString(forBaseURL baseURL: HTTPURL, readingProgression: ReadingProgression) -> String {
        serializeJSONString(json(forBaseURL: baseURL, readingProgression: readingProgression)) ?? "[]"
    }

    /// Builds a list of spreads for the given Publication.
    ///
    /// - Parameters:
    ///   - publication: The Publication to build the spreads for.
    ///   - readingProgression: Reading progression direction used to layout the pages.
    ///   - spread: Indicates whether two pages are displayed side-by-side.
    ///   - offsetFirstPage: Indicates if the first page should be displayed in its own spread.
    static func makeSpreads(
        for publication: Publication,
        readingOrder: [Link],
        readingProgression: ReadingProgression,
        spread: Bool,
        offsetFirstPage: Bool? = nil
    ) -> [EPUBSpread] {
        spread
            ? makeTwoPagesSpreads(for: publication, readingOrder: readingOrder, readingProgression: readingProgression, offsetFirstPage: offsetFirstPage)
            : makeOnePageSpreads(readingOrder: readingOrder)
    }

    /// Builds a list of one-page spreads for the given Publication.
    private static func makeOnePageSpreads(
        readingOrder: [Link]
    ) -> [EPUBSpread] {
        readingOrder.enumerated().map { index, link in
            .single(EPUBSingleSpread(
                resource: EPUBSpreadResource(index: index, link: link)
            ))
        }
    }

    /// Builds a list of two-page spreads for the given Publication.
    private static func makeTwoPagesSpreads(
        for publication: Publication,
        readingOrder: [Link],
        readingProgression: ReadingProgression,
        offsetFirstPage: Bool?
    ) -> [EPUBSpread] {
        var spreads: [EPUBSpread] = []

        var index = 0
        while index < readingOrder.count {
            var first = readingOrder[index]

            // If the `offsetFirstPage` is set, we override the default
            // position of the first resource to display it either:
            // - (true) on its own and centered
            // - (false) next to the second resource
            if index == 0, let offsetFirstPage = offsetFirstPage {
                first.properties.page = offsetFirstPage ? .center : nil
            }

            let nextIndex = index + 1

            // To be displayed together, two pages must be part of a fixed
            // layout publication and have consecutive position hints
            // (Properties.Page).
            if
                let second = readingOrder.getOrNil(nextIndex),
                publication.metadata.layout == .fixed,
                areConsecutive(first, second, readingProgression: publication.metadata.readingProgression)
            {
                spreads.append(.double(
                    EPUBDoubleSpread(
                        first: EPUBSpreadResource(index: index, link: first),
                        second: EPUBSpreadResource(index: nextIndex, link: second)
                    )
                ))
                index += 1 // Skips the consumed "second" page

            } else {
                spreads.append(.single(
                    EPUBSingleSpread(
                        resource: EPUBSpreadResource(index: index, link: first)
                    )
                ))
            }

            index += 1
        }

        return spreads
    }

    /// Two resources are consecutive if their position hint (Properties.Page)
    /// are paired according to the reading progression.
    private static func areConsecutive(
        _ first: Link,
        _ second: Link,
        readingProgression: ReadiumShared.ReadingProgression
    ) -> Bool {
        // Here we use the default publication reading progression instead
        // of the custom one provided, otherwise the page position hints
        // might be wrong, and we could end up with only one-page spreads.
        switch readingProgression {
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

/// A resource displayed in a spread, with its reading order index.
struct EPUBSpreadResource {
    /// Index of the resource in the reading order.
    let index: ReadingOrder.Index
    /// Link to the resource.
    let link: Link

    /// Returns a JSON representation of the resource for the spread scripts.
    func json(forBaseURL baseURL: HTTPURL, page: Properties.Page) -> [String: Any] {
        [
            "index": index,
            "link": link.json,
            "url": link.url(relativeTo: baseURL).string,
            "page": page.rawValue,
        ]
    }
}

/// A spread displaying a single resource.
struct EPUBSingleSpread: EPUBSpreadProtocol, Loggable {
    /// The resource displayed in the spread.
    var resource: EPUBSpreadResource

    func contains(index: ReadingOrder.Index) -> Bool {
        resource.index == index
    }

    func positionCount(in readingOrder: ReadingOrder, positionsByReadingOrder: [[Locator]]) -> Int {
        positionsByReadingOrder.getOrNil(resource.index)?.count ?? 0
    }

    func json(forBaseURL baseURL: HTTPURL, readingProgression: ReadingProgression) -> [[String: Any]] {
        [
            resource.json(
                forBaseURL: baseURL,
                page: resource.link.properties.page ?? readingProgression.startingPage
            ),
        ]
    }
}

/// A spread displaying two resources side by side (FXL only).
struct EPUBDoubleSpread: EPUBSpreadProtocol, Loggable {
    /// The leading resource in the reading progression.
    var first: EPUBSpreadResource
    /// The trailing resource in the reading progression.
    var second: EPUBSpreadResource

    /// Returns the left resource in the spread.
    func left(for readingProgression: ReadingProgression) -> EPUBSpreadResource {
        switch readingProgression {
        case .ltr:
            first
        case .rtl:
            second
        }
    }

    /// Returns the right resource in the spread.
    func right(for readingProgression: ReadingProgression) -> EPUBSpreadResource {
        switch readingProgression {
        case .ltr:
            second
        case .rtl:
            first
        }
    }

    func contains(index: ReadingOrder.Index) -> Bool {
        first.index == index || second.index == index
    }

    func positionCount(in readingOrder: ReadingOrder, positionsByReadingOrder: [[Locator]]) -> Int {
        let firstPositions = positionsByReadingOrder.getOrNil(first.index)?.count ?? 0
        let secondPositions = positionsByReadingOrder.getOrNil(second.index)?.count ?? 0
        return firstPositions + secondPositions
    }

    func json(forBaseURL baseURL: HTTPURL, readingProgression: ReadingProgression) -> [[String: Any]] {
        [
            left(for: readingProgression).json(forBaseURL: baseURL, page: .left),
            right(for: readingProgression).json(forBaseURL: baseURL, page: .right),
        ]
    }
}

extension Array where Element == EPUBSpread {
    /// Returns the index of the first spread containing a resource with the
    /// given `href`.
    func firstIndexWithReadingOrderIndex(_ index: ReadingOrder.Index) -> Int? {
        firstIndex { spread in
            spread.contains(index: index)
        }
    }
}
