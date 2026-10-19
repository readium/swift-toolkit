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
    private let layout: TimelineLayout<Int>

    /// - Parameter pageCounts: Page count of each reading order resource, by
    ///   index.
    package init(readingOrder: [Link], pageCounts: [Int?]) {
        layout = TimelineLayout(
            readingOrder: readingOrder,
            lengths: pageCounts,
            offset: TimelineOffset.page
        )
    }

    package var end: TimelinePosition? {
        layout.end
    }

    package func position(of link: Link) -> TimelinePosition? {
        let url = link.url()
        guard let index = layout.index(of: url) else {
            return nil
        }
        let page = url.fragment?.pdfSelector?.page ?? 1
        return layout.position(at: index, offset: clamped(page - 1, at: index))
    }

    /// The page is read from a `page=` fragment, as the navigator does, then
    /// from the position in the publication, then from the progression in
    /// the resource.
    package func position(of locator: Locator) -> TimelinePosition? {
        guard let index = layout.index(of: locator.href) else {
            return nil
        }

        let locations = locator.locations
        let page = locations.page.flatMap { $0 >= 1 ? $0 - 1 : nil }
            ?? pageFromPosition(locations.position, at: index)
            ?? pageFromProgression(locations.progression, at: index)
            ?? 0

        return layout.position(at: index, offset: clamped(page, at: index))
    }

    package func bounds(ofResource href: any URLConvertible) -> (start: TimelinePosition, end: TimelinePosition?)? {
        layout.bounds(ofResource: href)
    }

    /// Page index in the resource at `index` of the given 1-based position in
    /// the publication, or `nil` when it is outside the resource or the
    /// preceding page counts are unknown.
    private func pageFromPosition(_ position: Int?, at index: Int) -> Int? {
        guard
            let position, position >= 1,
            let startOffset = layout.startOffset(ofResourceAt: index)
        else {
            return nil
        }
        let page = position - 1 - startOffset
        guard page >= 0, layout.length(ofResourceAt: index).map({ page < $0 }) ?? true else {
            return nil
        }
        return page
    }

    /// Page index in the resource at `index` of the given progression in the
    /// resource, or `nil` when its page count is unknown.
    private func pageFromProgression(_ progression: Double?, at index: Int) -> Int? {
        guard
            let progression,
            let pageCount = layout.length(ofResourceAt: index)
        else {
            return nil
        }
        let page = (min(max(0, progression), 1) * Double(pageCount)).rounded(.down)
        return Int(page)
    }

    /// Clamps `page` to the pages of the resource at `index`.
    private func clamped(_ page: Int, at index: Int) -> Int {
        let page = max(0, page)
        guard let pageCount = layout.length(ofResourceAt: index) else {
            return page
        }
        return min(page, pageCount - 1)
    }
}
