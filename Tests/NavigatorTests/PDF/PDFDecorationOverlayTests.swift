//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreGraphics
@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

/// Tests for the grouping of render items into render units, which merges
/// `.viewMerged` decorations per (group, style) across a page.
struct PDFDecorationOverlayTests {
    @Test func nonMergedItemsKeepTheirOrder() throws {
        let items = [
            makeItem(id: "h1", styleId: .highlight, group: "a", renderer: viewRenderer),
            makeItem(id: "h2", styleId: .underline, group: "a", renderer: drawRenderer),
        ]
        let units = items.renderUnits()
        try #require(units.count == 2)
        #expect(singleId(of: units[0]) == "h1")
        #expect(singleId(of: units[1]) == "h2")
    }

    @Test func nonContiguousMasksInOneGroupMergeAtTheFirstMaskPosition() throws {
        let items = [
            makeItem(id: "m1", styleId: .mask, group: "a", renderer: mergedRenderer, rects: [CGRect(x: 0, y: 0, width: 10, height: 10)]),
            makeItem(id: "h1", styleId: .highlight, group: "a", renderer: viewRenderer),
            makeItem(id: "m2", styleId: .mask, group: "a", renderer: mergedRenderer, rects: [CGRect(x: 0, y: 20, width: 10, height: 10)]),
        ]
        let units = items.renderUnits()
        try #require(units.count == 2)

        guard case let .merged(merged) = units[0] else {
            Issue.record("expected a merged unit at the first mask's position")
            return
        }
        #expect(merged.map(\.decoration.id) == ["m1", "m2"])
        #expect(merged.flatMap(\.rects) == [
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 0, y: 20, width: 10, height: 10),
        ])
        #expect(singleId(of: units[1]) == "h1")
    }

    @Test func masksInDifferentGroupsStaySeparate() throws {
        let items = [
            makeItem(id: "m1", styleId: .mask, group: "a", renderer: mergedRenderer),
            makeItem(id: "m2", styleId: .mask, group: "b", renderer: mergedRenderer),
        ]
        let units = items.renderUnits()
        try #require(units.count == 2)
        #expect(mergedIds(of: units[0]) == ["m1"])
        #expect(mergedIds(of: units[1]) == ["m2"])
    }

    @Test func differentMergedStylesInOneGroupStaySeparate() throws {
        let items = [
            makeItem(id: "m1", styleId: .mask, group: "a", renderer: mergedRenderer),
            makeItem(id: "s1", styleId: "custom-merged", group: "a", renderer: mergedRenderer),
            makeItem(id: "m2", styleId: .mask, group: "a", renderer: mergedRenderer),
        ]
        let units = items.renderUnits()
        try #require(units.count == 2)
        #expect(mergedIds(of: units[0]) == ["m1", "m2"])
        #expect(mergedIds(of: units[1]) == ["s1"])
    }
}

// MARK: - Helpers

private let viewRenderer = PDFDecorationTemplate.Renderer.view { _, _ in UIView() }
private let drawRenderer = PDFDecorationTemplate.Renderer.draw { _, _, _ in }
private let mergedRenderer = PDFDecorationTemplate.Renderer.viewMerged { _, _ in UIView() }

private func makeItem(
    id: Decoration.Id,
    styleId: Decoration.Style.Id,
    group: DecorationGroup,
    renderer: PDFDecorationTemplate.Renderer,
    rects: [CGRect] = []
) -> PDFDecorationRenderItem {
    PDFDecorationRenderItem(
        decoration: Decoration(
            id: id,
            locator: Locator(href: AnyURL(string: "publication.pdf")!, mediaType: .pdf),
            style: Decoration.Style(id: styleId)
        ),
        group: group,
        rects: rects,
        template: PDFDecorationTemplate(layout: .boxes, renderer: renderer)
    )
}

private func singleId(of unit: PDFDecorationRenderUnit) -> Decoration.Id? {
    guard case let .single(item) = unit else {
        return nil
    }
    return item.decoration.id
}

private func mergedIds(of unit: PDFDecorationRenderUnit) -> [Decoration.Id]? {
    guard case let .merged(items) = unit else {
        return nil
    }
    return items.map(\.decoration.id)
}
