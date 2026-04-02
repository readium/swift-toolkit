//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing
import UIKit

private let fixtures = Fixtures(path: "Toolkit/Extensions")
private let image = UIImage(contentsOfFile: fixtures.url(for: "image.jpg").path)!

@Suite struct UIImageTests {
    @Suite("scaleToFit(maxSize:)") struct ScaleToFit {
        // image.jpg is 598×800

        @Test func returnsSameImageWhenSizeMatches() {
            #expect(image.scaleToFit(maxSize: image.size) == image)
        }

        @Test(arguments: [
            CGSize(width: 1000, height: 800),
            CGSize(width: 598, height: 1000),
            CGSize(width: 1000, height: 1000),
        ])
        func returnsSameImageWhenMaxSizeIsLarger(maxSize: CGSize) {
            #expect(image.scaleToFit(maxSize: maxSize) == image)
        }

        @Test func scalesDownFittingHeight() {
            let actual = image.scaleToFit(maxSize: CGSize(width: 300, height: 400))
            #expect(actual.size == CGSize(width: 299, height: 400))
        }

        @Test func scalesDownFittingWidth() {
            let actual = image.scaleToFit(maxSize: CGSize(width: 399, height: 800))
            #expect(actual.size == CGSize(width: 399, height: 534))
        }
    }

    @Suite("fromSVG()") struct FromSVG {
        @Test func returnsNilForEmptyData() {
            #expect(UIImage.fromSVG(Data(), maxSize: CGSize(width: 400, height: 600)) == nil)
        }

        @Test func returnsNilForNonSVGData() {
            #expect(UIImage.fromSVG(fixtures.data(at: "image.jpg"), maxSize: CGSize(width: 400, height: 600)) == nil)
        }

        @Test func rendersAtNativeSizeWhenSmaller() throws {
            // SVG canvas is 100×150; it must not be upscaled.
            let image = try #require(UIImage.fromSVG(fixtures.data(at: "cover-svg.svg"), maxSize: CGSize(width: 400, height: 600)))
            #expect(image.size.width == 100)
            #expect(image.size.height == 150)
        }

        @Test func scalesDownPreservingAspectRatio() throws {
            // SVG canvas is 100×150; at maxSize 75×75 the aspect ratio matches exactly.
            let maxSize = CGSize(width: 75, height: 75)
            let image = try #require(UIImage.fromSVG(fixtures.data(at: "cover-svg.svg"), maxSize: maxSize))
            #expect(image.size.width == 50)
            #expect(image.size.height == 75)
        }
    }
}
