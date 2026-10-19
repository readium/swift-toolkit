//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Resolves the locations of a PDF publication into positions on its
/// timeline, from the page count of each document in its reading order.
///
/// A page from a link or a locator is clamped to the pages of its document,
/// when its page count is known. A missing or non-positive page count is
/// unknown.
package struct PDFTimelinePositionResolver: TimelinePositionResolver {
    private let readingOrder: [Link]

    /// Page count of each reading order resource.
    private let pageCounts: [Int?]

    /// Number of pages before each reading order resource, `nil` when a
    /// preceding page count is unknown.
    private let startOffsets: [Int?]

    /// Page count of the publication, `nil` when a page count is unknown.
    private let totalPageCount: Int?

    /// - Parameter pageCounts: Page count of each reading order resource, by
    ///   index.
    package init(readingOrder: [Link], pageCounts: [Int?]) {
        self.readingOrder = readingOrder
        self.pageCounts = readingOrder.indices.map { index in
            pageCounts.getOrNil(index).flatMap { $0 }.flatMap { $0 > 0 ? $0 : nil }
        }

        var startOffsets: [Int?] = []
        var offset: Int? = 0
        for pageCount in self.pageCounts {
            startOffsets.append(offset)
            offset = offset.flatMap { offset in pageCount.map { offset + $0 } }
        }
        self.startOffsets = startOffsets
        totalPageCount = offset
    }

    package var end: TimelinePosition? {
        guard !readingOrder.isEmpty else {
            return nil
        }
        return end(ofResourceAt: readingOrder.count - 1)
    }

    package func position(of link: Link) -> TimelinePosition? {
        let url = link.url()
        guard let index = readingOrder.firstIndexWithHREF(url) else {
            return nil
        }
        let page = url.fragment?.pdfSelector?.page ?? 1
        return position(at: index, page: clamped(page - 1, at: index))
    }

    /// The page is read from a `page=` fragment, as the navigator does, then
    /// from the position in the publication, then from the progression in
    /// the resource.
    package func position(of locator: Locator) -> TimelinePosition? {
        guard let index = readingOrder.firstIndexWithHREF(locator.href) else {
            return nil
        }

        let locations = locator.locations
        let page = locations.page.flatMap { $0 >= 1 ? $0 - 1 : nil }
            ?? pageFromPosition(locations.position, at: index)
            ?? pageFromProgression(locations.progression, at: index)
            ?? 0

        return position(at: index, page: clamped(page, at: index))
    }

    package func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)? {
        guard let index = readingOrder.firstIndexWithHREF(href) else {
            return nil
        }
        return (position(at: index, page: 0), end(ofResourceAt: index))
    }

    /// Page index in the resource at `index` of the given 1-based position in
    /// the publication, or `nil` when it is outside the resource or the
    /// preceding page counts are unknown.
    private func pageFromPosition(_ position: Int?, at index: Int) -> Int? {
        guard
            let position, position >= 1,
            let startOffset = startOffsets[index]
        else {
            return nil
        }
        let page = position - 1 - startOffset
        guard page >= 0, pageCounts[index].map({ page < $0 }) ?? true else {
            return nil
        }
        return page
    }

    /// Page index in the resource at `index` of the given progression in the
    /// resource, or `nil` when its page count is unknown.
    private func pageFromProgression(_ progression: Double?, at index: Int) -> Int? {
        guard
            let progression,
            let pageCount = pageCounts[index]
        else {
            return nil
        }
        let page = (min(max(0, progression), 1) * Double(pageCount)).rounded(.down)
        return Int(page)
    }

    /// Clamps `page` to the pages of the resource at `index`.
    private func clamped(_ page: Int, at index: Int) -> Int {
        let page = max(0, page)
        guard let pageCount = pageCounts[index] else {
            return page
        }
        return min(page, pageCount - 1)
    }

    /// End of the reading order resource at `index`, or `nil` when its page
    /// count is unknown.
    private func end(ofResourceAt index: Int) -> TimelinePosition? {
        guard let pageCount = pageCounts[index] else {
            return nil
        }
        let end = position(at: index, page: pageCount)

        // The end of the publication is at 100%, even when the page count of
        // a preceding resource is unknown.
        guard index < readingOrder.count - 1 else {
            return TimelinePosition(
                readingOrderIndex: index,
                offset: end.offset,
                totalOffset: end.totalOffset,
                progression: end.progression,
                totalProgression: 1
            )
        }
        return end
    }

    private func position(at index: Int, page: Int) -> TimelinePosition {
        let pageCount = pageCounts[index]
        let totalOffset = startOffsets[index].map { $0 + page }

        return TimelinePosition(
            readingOrderIndex: index,
            offset: .page(page),
            totalOffset: totalOffset.map { .page($0) },
            progression: pageCount.map { Double(page) / Double($0) },
            totalProgression: totalOffset.flatMap { totalOffset in
                totalPageCount.map { Double(totalOffset) / Double($0) }
            }
        )
    }
}
