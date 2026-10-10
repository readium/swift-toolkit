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

enum PDFDecorationTemplateTests {
    struct LayoutRects {
        /// Two line boxes in PDF user space; their union is (5, 85, 80, 25).
        let lineRects = [
            CGRect(x: 10, y: 100, width: 50, height: 10),
            CGRect(x: 5, y: 85, width: 80, height: 10),
        ]
        let pageBounds = CGRect(x: 0, y: 0, width: 432, height: 648)

        @Test func boxesWrapKeepsLineBoxes() {
            let rects = makeTemplate(layout: .boxes, width: .wrap).layoutRects(for: lineRects, pageBounds: pageBounds)
            #expect(rects == lineRects)
        }

        @Test func boundsIsTheUnionOfLineBoxes() {
            let rects = makeTemplate(layout: .bounds, width: .wrap).layoutRects(for: lineRects, pageBounds: pageBounds)
            #expect(rects == [CGRect(x: 5, y: 85, width: 80, height: 25)])
        }

        @Test func boundsWidthStretchesEachBoxToTheBoundingBox() {
            let rects = makeTemplate(layout: .boxes, width: .bounds).layoutRects(for: lineRects, pageBounds: pageBounds)
            #expect(rects == [
                CGRect(x: 5, y: 100, width: 80, height: 10),
                CGRect(x: 5, y: 85, width: 80, height: 10),
            ])
        }

        @Test func pageWidthStretchesEachBoxToThePage() {
            let rects = makeTemplate(layout: .boxes, width: .page).layoutRects(for: lineRects, pageBounds: pageBounds)
            #expect(rects == [
                CGRect(x: 0, y: 100, width: 432, height: 10),
                CGRect(x: 0, y: 85, width: 432, height: 10),
            ])
        }

        @Test func boundsLayoutWithPageWidth() {
            let rects = makeTemplate(layout: .bounds, width: .page).layoutRects(for: lineRects, pageBounds: pageBounds)
            #expect(rects == [CGRect(x: 0, y: 85, width: 432, height: 25)])
        }

        @Test func pageWidthAccountsForCropBoxOrigin() {
            let bounds = CGRect(x: 90, y: 72, width: 300, height: 500)
            let rects = makeTemplate(layout: .bounds, width: .page).layoutRects(for: lineRects, pageBounds: bounds)
            #expect(rects == [CGRect(x: 90, y: 85, width: 300, height: 25)])
        }

        @Test func singleRectPassesThrough() {
            let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
            let rects = makeTemplate(layout: .boxes, width: .wrap).layoutRects(for: [rect], pageBounds: pageBounds)
            #expect(rects == [rect])
        }

        @Test func emptyInputYieldsNoRects() {
            let rects = makeTemplate(layout: .boxes, width: .wrap).layoutRects(for: [], pageBounds: pageBounds)
            #expect(rects.isEmpty)
        }

        @Test func expandInflatesEachLineBox() {
            let rects = makeTemplate(layout: .boxes, width: .wrap).layoutRects(for: lineRects, pageBounds: pageBounds, expand: 2)
            #expect(rects == [
                CGRect(x: 8, y: 98, width: 54, height: 14),
                CGRect(x: 3, y: 83, width: 84, height: 14),
            ])
        }

        @Test func expandInflatesBeforeTheUnion() {
            let rects = makeTemplate(layout: .bounds, width: .wrap).layoutRects(for: lineRects, pageBounds: pageBounds, expand: 2)
            #expect(rects == [CGRect(x: 3, y: 83, width: 84, height: 29)])
        }

        @Test func pageWidthOverwritesHorizontalExpansion() {
            let rects = makeTemplate(layout: .boxes, width: .page).layoutRects(for: lineRects, pageBounds: pageBounds, expand: 2)
            #expect(rects == [
                CGRect(x: 0, y: 98, width: 432, height: 14),
                CGRect(x: 0, y: 83, width: 432, height: 14),
            ])
        }

        @Test func boundsWidthOverwritesHorizontalExpansion() {
            let rects = makeTemplate(layout: .boxes, width: .bounds).layoutRects(for: lineRects, pageBounds: pageBounds, expand: 2)
            #expect(rects == [
                CGRect(x: 3, y: 98, width: 84, height: 14),
                CGRect(x: 3, y: 83, width: 84, height: 14),
            ])
        }

        @Test func expandedRectsMayExceedThePageBounds() {
            let rect = CGRect(x: 0, y: 0, width: 10, height: 10)
            let rects = makeTemplate(layout: .boxes, width: .wrap).layoutRects(for: [rect], pageBounds: pageBounds, expand: 5)
            #expect(rects == [CGRect(x: -5, y: -5, width: 20, height: 20)])
        }
    }

    struct DefaultTemplates {
        @Test func registersAllTheBuiltInStyles() {
            let templates = PDFDecorationTemplate.defaultTemplates()
            #expect(Set(templates.keys) == [.highlight, .underline, .strikethrough, .outline, .mask])
        }

        @Test func strikethroughAndOutlineUseTheViewRenderer() throws {
            let templates = PDFDecorationTemplate.defaultTemplates()
            for id in [Decoration.Style.Id.strikethrough, .outline] {
                guard case .view = try #require(templates[id]).renderer else {
                    Issue.record("expected a .view renderer for \(id.rawValue)")
                    return
                }
            }
        }

        @Test func maskUsesTheViewMergedRenderer() throws {
            guard case .viewMerged = try #require(PDFDecorationTemplate.defaultTemplates()[.mask]).renderer else {
                Issue.record("expected a .viewMerged renderer for mask")
                return
            }
        }

        @MainActor @Test func strikethroughHonorsTheTintAndCentersTheLine() throws {
            let template = PDFDecorationTemplate.strikethrough(defaultTint: .yellow, lineWeight: 2)
            guard case let .view(makeView) = template.renderer else {
                Issue.record("expected a .view renderer")
                return
            }
            let frame = CGRect(x: 0, y: 0, width: 100, height: 20)
            let view = makeView(makeDecoration(style: .strikethrough(tint: .red)), frame)
            let line = try #require(view.subviews.first)
            #expect(line.backgroundColor == .red)
            #expect(line.frame == CGRect(x: 0, y: 9, width: 100, height: 2))
        }

        @MainActor @Test func outlineHonorsTheTint() {
            let template = PDFDecorationTemplate.outline(defaultTint: .yellow, lineWidth: 3)
            guard case let .view(makeView) = template.renderer else {
                Issue.record("expected a .view renderer")
                return
            }
            let view = makeView(makeDecoration(style: .outline(tint: .blue)), CGRect(x: 0, y: 0, width: 100, height: 20))
            #expect(view.layer.borderColor == UIColor.blue.cgColor)
            #expect(view.layer.borderWidth == 3)
        }

        @MainActor @Test func maskUsesTheFirstDecorationTint() throws {
            let template = PDFDecorationTemplate.mask(defaultTint: .yellow, alpha: 0.5)
            guard case let .viewMerged(makeView) = template.renderer else {
                Issue.record("expected a .viewMerged renderer")
                return
            }
            let pageFrame = CGRect(x: 0, y: 0, width: 432, height: 648)
            let view = makeView(
                [
                    (makeDecoration(style: .mask(tint: .green)), [CGRect(x: 10, y: 10, width: 50, height: 10)]),
                    (makeDecoration(style: .mask(tint: .purple)), [CGRect(x: 10, y: 40, width: 50, height: 10)]),
                ],
                pageFrame
            )
            #expect(view.backgroundColor == UIColor.green.withAlphaComponent(0.5))
            let mask = try #require(view.layer.mask as? CAShapeLayer)
            #expect(mask.fillRule == .evenOdd)
            // Under the even-odd rule, both decorations' rects are holes in
            // the page-sized fill.
            let path = try #require(mask.path)
            #expect(!path.contains(CGPoint(x: 15, y: 15), using: .evenOdd))
            #expect(!path.contains(CGPoint(x: 15, y: 45), using: .evenOdd))
            #expect(path.contains(CGPoint(x: 200, y: 300), using: .evenOdd))
        }

        @MainActor @Test func maskFallsBackToTheDefaultTint() {
            let template = PDFDecorationTemplate.mask(defaultTint: .yellow, alpha: 0.5)
            guard case let .viewMerged(makeView) = template.renderer else {
                Issue.record("expected a .viewMerged renderer")
                return
            }
            let view = makeView(
                [(makeDecoration(style: .init(id: .mask)), [CGRect(x: 10, y: 10, width: 50, height: 10)])],
                CGRect(x: 0, y: 0, width: 432, height: 648)
            )
            #expect(view.backgroundColor == UIColor.yellow.withAlphaComponent(0.5))
        }
    }

    struct PageSpaceConversion {
        @Test func flipsToTopLeftOrigin() {
            let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
                .convertedFromPDFSpace(pageBounds: CGRect(x: 0, y: 0, width: 432, height: 648))
            #expect(rect == CGRect(x: 10, y: 588, width: 30, height: 40))
        }

        @Test func accountsForCropBoxOrigin() {
            let rect = CGRect(x: 100, y: 100, width: 50, height: 20)
                .convertedFromPDFSpace(pageBounds: CGRect(x: 90, y: 72, width: 300, height: 500))
            #expect(rect == CGRect(x: 10, y: 452, width: 50, height: 20))
        }
    }
}

// MARK: - Helpers

private func makeTemplate(layout: PDFDecorationTemplate.Layout, width: PDFDecorationTemplate.Width) -> PDFDecorationTemplate {
    PDFDecorationTemplate(layout: layout, width: width, renderer: .draw { _, _, _ in })
}

private func makeDecoration(style: Decoration.Style) -> Decoration {
    Decoration(
        id: "decoration",
        locator: Locator(href: AnyURL(string: "publication.pdf")!, mediaType: .pdf),
        style: style
    )
}
