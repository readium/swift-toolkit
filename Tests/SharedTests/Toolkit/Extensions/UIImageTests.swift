//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing
import UIKit

private let fixtures = Fixtures(path: "Toolkit/Extensions")
/// image.jpg is 598×800
private let image = UIImage(contentsOfFile: fixtures.url(for: "image.jpg").path)!
/// readium.png is 167×167
private let squareImage = UIImage(contentsOfFile: fixtures.url(for: "readium.png").path)!
/// cc-a-shared-culture.jpg is 376×500
private let portraitImage = UIImage(contentsOfFile: fixtures.url(for: "cc-a-shared-culture.jpg").path)!

enum UIImageTests {
    @Suite("scaleToFit(maxSize:)") struct ScaleToFit {
        /// The early-return code path is image-agnostic; one set of cases is enough.
        @Test func returnsSelfWhenFits() {
            #expect(image.scaleToFit(maxSize: image.size) === image)
        }

        @Test(arguments: [
            CGSize(width: 1000, height: 800), // width-only larger
            CGSize(width: 598, height: 1000), // height-only larger
            CGSize(width: 1000, height: 1000), // both larger
        ])
        func returnsSelfWhenMaxSizeIsLarger(maxSize: CGSize) {
            #expect(image.scaleToFit(maxSize: maxSize) === image)
        }

        @Suite("PNG square image") struct PNGSquareImage {
            // readium.png is 167×167

            @Test func scalesDownFittingWidth() throws {
                // Width-constrained (100 < 167); square stays square → 100×100
                let actual = squareImage.scaleToFit(maxSize: CGSize(width: 100, height: 200))
                #expect(actual.size == CGSize(width: 100, height: 100))
                try assertImageMatchesFixture(actual, fixture: "readium-scaled.png")
            }

            @Test func scalesDownFittingHeight() throws {
                // Height-constrained (100 < 167); square stays square → 100×100
                let actual = squareImage.scaleToFit(maxSize: CGSize(width: 200, height: 100))
                #expect(actual.size == CGSize(width: 100, height: 100))
                try assertImageMatchesFixture(actual, fixture: "readium-scaled.png")
            }

            @Test func scalesDownFittingBothAxes() throws {
                // Both axes limited equally → 100×100
                let actual = squareImage.scaleToFit(maxSize: CGSize(width: 100, height: 100))
                #expect(actual.size == CGSize(width: 100, height: 100))
                try assertImageMatchesFixture(actual, fixture: "readium-scaled.png")
            }

            @Test func scalesDownWhenOnlyWidthExceedsMax() throws {
                // Width 167 > 100 (exceeds), height 167 ≤ 300 (fits) → still scales → 100×100
                let actual = squareImage.scaleToFit(maxSize: CGSize(width: 100, height: 300))
                #expect(actual.size == CGSize(width: 100, height: 100))
                try assertImageMatchesFixture(actual, fixture: "readium-scaled.png")
            }
        }

        @Suite("JPEG portrait image") struct JPEGPortraitImage {
            // cc-a-shared-culture.jpg is 376×500

            @Test func scalesDownFittingWidth() throws {
                // Width scale (188/376 = 0.5) < height scale (300/500 = 0.6) → width limits → 188×250
                let actual = portraitImage.scaleToFit(maxSize: CGSize(width: 188, height: 300))
                #expect(actual.size == CGSize(width: 188, height: 250))
                try assertImageMatchesFixture(actual, fixture: "cc-a-shared-culture-scaled.png")
            }

            @Test func scalesDownFittingHeight() throws {
                // Height scale (250/500 = 0.5) < width scale (300/376 ≈ 0.8) → height limits → 188×250
                let actual = portraitImage.scaleToFit(maxSize: CGSize(width: 300, height: 250))
                #expect(actual.size == CGSize(width: 188, height: 250))
                try assertImageMatchesFixture(actual, fixture: "cc-a-shared-culture-scaled.png")
            }

            @Test func scalesDownWhenOnlyHeightExceedsMax() throws {
                // Width 376 ≤ 400 (fits), height 500 > 250 (exceeds) → still scales → 188×250
                let actual = portraitImage.scaleToFit(maxSize: CGSize(width: 400, height: 250))
                #expect(actual.size == CGSize(width: 188, height: 250))
                try assertImageMatchesFixture(actual, fixture: "cc-a-shared-culture-scaled.png")
            }
        }

        @Suite("SVG image") struct SVGImage {
            /// cover.svg is 1400×2100 (portrait, aspect ratio 2:3)
            let svgData = fixtures.data(at: "cover.svg")

            @Test func scalesDownFittingWidth() throws {
                // Width-constrained: 1400×2100 → 500×750
                let actual = try #require(UIImage.fromSVG(svgData, maxSize: CGSize(width: 500, height: 800)))
                #expect(actual.size == CGSize(width: 500, height: 750))
                try assertImageMatchesFixture(actual, fixture: "cover-svg-fitting-width.png")
            }

            @Test func scalesDownFittingHeight() throws {
                // Height-constrained: 1400×2100 → 267×400
                let actual = try #require(UIImage.fromSVG(svgData, maxSize: CGSize(width: 400, height: 400)))
                #expect(actual.size == CGSize(width: 267, height: 400))
                try assertImageMatchesFixture(actual, fixture: "cover-svg-fitting-height.png")
            }

            @Test func scalesDownFittingBothAxes() throws {
                // Both axes: 1400×2100 → 350×525
                let actual = try #require(UIImage.fromSVG(svgData, maxSize: CGSize(width: 350, height: 525)))
                #expect(actual.size == CGSize(width: 350, height: 525))
                try assertImageMatchesFixture(actual, fixture: "cover-svg-fitting-both-axes.png")
            }
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
            // SVG canvas is 1400×2100; it must not be upscaled.
            let image = try #require(UIImage.fromSVG(fixtures.data(at: "cover.svg"), maxSize: CGSize(width: 3000, height: 3000)))
            #expect(image.size.width == 1400)
            #expect(image.size.height == 2100)
        }

        @Test func scalesDownPreservingAspectRatio() throws {
            // SVG canvas is 1400×2100 (aspect ratio 2:3); at maxSize 75×75 height limits → 50×75
            let maxSize = CGSize(width: 75, height: 75)
            let image = try #require(UIImage.fromSVG(fixtures.data(at: "cover.svg"), maxSize: maxSize))
            #expect(image.size.width == 50)
            #expect(image.size.height == 75)
        }
    }
}

// MARK: - Helpers

/// - Parameter record: Set to `true` once, run the tests to write
///   golden fixture files, then set back to `false`.
private func assertImageMatchesFixture(
    _ actual: UIImage,
    fixture name: String,
    record: Bool = false,
    filePath: StaticString = #filePath
) throws {
    if record {
        // Derive the fixtures path from the test file's source path so we
        // write golden files directly into the source tree (not the bundle).
        // Test file: .../Tests/SharedTests/Toolkit/Extensions/UIImageTests.swift
        // Fixtures:  .../Tests/SharedTests/Fixtures/Toolkit/Extensions/
        let testFileURL = URL(fileURLWithPath: "\(filePath)")
        let fixtureURL = testFileURL
            .deletingLastPathComponent() // Extensions/
            .deletingLastPathComponent() // Toolkit/
            .deletingLastPathComponent() // SharedTests root
            .appendingPathComponent("Fixtures/Toolkit/Extensions/\(name)")
        let data = try #require(actual.pngData())
        try data.write(to: fixtureURL)
        Issue.record("Recorded \(name) — set record = false before committing")
        return
    }

    // Load the golden file as raw Data to avoid a lossy UIImage
    // decode+re-encode round-trip.
    let actualData = try #require(actual.pngData())
    let expectedData = try Data(contentsOf: fixtures.url(for: name).url)
    #expect(actualData == expectedData)
}
