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

/// Width of a `0` in Iowan Old Style at 16pt, the width of a character used
/// by the navigator at a 100% font size: 65 of them measure 578pt.
private let iowanWidth = 578.0 / 65

/// Checks the number of columns of `layout`, and its line length with a
/// tolerance for the floating-point errors.
private func expectLayout(
    _ layout: LayoutResolver.Layout,
    _ expected: LayoutResolver.Layout,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(layout.colCount == expected.colCount, sourceLocation: sourceLocation)
    #expect(abs(layout.lineLength - expected.lineLength) < 0.001, sourceLocation: sourceLocation)
}

struct LayoutResolverTests {
    let resolver = LayoutResolver()

    /// Fixture width of a character, so that the line lengths in points are
    /// ten times the numbers of characters.
    let characterWidth = 10.0

    // MARK: - Scrolled Layout

    @Test func scrolledHorizontalLayout() {
        let layout = resolver.layout(
            scroll: true,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: .infinity,
            pageMargins: 1.0,
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 800, height: 600),
            insets: .zero
        )

        // colCount is always 1 for scroll
        #expect(layout.colCount == 1)
        // available = 800 - 30 * 2 = 740
        #expect(layout.lineLength == 740.0)
    }

    @Test func scrolledVerticalTextUsesHeight() {
        let layout = resolver.layout(
            scroll: true,
            verticalText: true,
            columnCount: nil,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: .infinity,
            pageMargins: 1.0,
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 800, height: 600),
            insets: .zero
        )

        #expect(layout.colCount == 1)
        // available = 600 (height) - 30 * 2 = 540
        #expect(layout.lineLength == 540.0)
    }

    @Test func scrolledLayoutClampsMaximalLineLength() {
        let layout = resolver.layout(
            scroll: true,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: 60, // 600
            pageMargins: 1.0,
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 1000, height: 800),
            insets: .zero
        )

        #expect(layout.colCount == 1)
        // available = 1000 - 60 = 940, clamped to max 600
        #expect(layout.lineLength == 600.0)
    }

    @Test func scrolledLayoutWithSafeAreaInsets() {
        let layout = resolver.layout(
            scroll: true,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: .infinity,
            pageMargins: 1.0, // 30
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 800, height: 600),
            insets: UIEdgeInsets(top: 10, left: 50, bottom: 10, right: 40)
        )

        #expect(layout.colCount == 1)
        // insets max(50, 40) = 50 > page margins 30 -> margins = 50
        // available = 800 - 50 * 2 = 700
        #expect(layout.lineLength == 700.0)
    }

    @Test func scrolledVerticalTextWithInsets() {
        let layout = resolver.layout(
            scroll: true,
            verticalText: true,
            columnCount: nil,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: .infinity,
            pageMargins: 1.0, // 30
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 800, height: 600),
            insets: UIEdgeInsets(top: 50, left: 100, bottom: 40, right: 100)
        )

        #expect(layout.colCount == 1)
        // insets max(50, 40) = 50 > page margins 30 -> margins = 50, the left
        // and right insets are ignored
        // available = 600 (height) - 50 * 2 = 500
        #expect(layout.lineLength == 500.0)
    }

    // MARK: - Paginated Layout Auto

    @Test func paginatedAutoSingleColumnOnPhone() {
        let layout = resolver.layout(
            scroll: false,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: .infinity,
            pageMargins: 1.0,
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 390, height: 844),
            insets: .zero
        )

        #expect(layout.colCount == 1)
        // minMarginWidth = 30 * 2 * 1 = 60
        // lineLength = (390 - 60) / 1 = 330
        #expect(layout.lineLength == 330.0)
    }

    @Test func paginatedAutoTwoColumnsOnWideScreen() {
        let layout = resolver.layout(
            scroll: false,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: .infinity,
            pageMargins: 1.0,
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 1400, height: 900),
            insets: .zero
        )

        #expect(layout.colCount == 2)
        // minMarginWidth = 30 * 2 * 2 = 120
        // lineLength = (1400 - 120) / 2 = 640
        #expect(layout.lineLength == 640.0)
    }

    @Test func paginatedAutoClampsToMaximalLineLength() {
        let layout = resolver.layout(
            scroll: false,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: 60, // 600
            pageMargins: 1.0,
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 1400, height: 900),
            insets: .zero
        )

        #expect(layout.colCount == 2)
        // available = (1400 - 120) / 2 = 640, clamped to max 600
        #expect(layout.lineLength == 600.0)
    }

    // MARK: - Paginated Layout N Columns

    @Test func paginatedRequestedColumnsHonoredWhenFitting() {
        let layout = resolver.layout(
            scroll: false,
            verticalText: false,
            columnCount: 2,
            optimalLineLength: 64, // 640
            minimalLineLength: 44, // 440
            maximalLineLength: .infinity,
            pageMargins: 1.0, // 30
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 1200, height: 800),
            insets: .zero
        )

        #expect(layout.colCount == 2)
        // available = 1200 - 30 * 2 * 2 = 1080
        // lineLength = 1080 / 2 = 540 >= minimalLineLength 440
        #expect(layout.lineLength == 540.0)
    }

    @Test func paginatedRequestedColumnsReducedWhenBelowMinimalLineLength() {
        let layout = resolver.layout(
            scroll: false,
            verticalText: false,
            columnCount: 2,
            optimalLineLength: 64, // 640
            minimalLineLength: 44, // 440
            maximalLineLength: .infinity,
            pageMargins: 1.0, // 30
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 600, height: 800),
            insets: .zero
        )

        // For 2 columns: available = 600 - 120 = 480 / 2 = 240 < 440
        // Reduces to 1 column: available = 600 - 60 = 540
        #expect(layout.colCount == 1)
        #expect(layout.lineLength == 540.0)
    }

    @Test func paginatedRequestedColumnsClampedToMaximalLineLength() {
        let layout = resolver.layout(
            scroll: false,
            verticalText: false,
            columnCount: 3,
            optimalLineLength: 64, // 640
            minimalLineLength: 44, // 440
            maximalLineLength: 52, // 520
            pageMargins: 1.0, // 30
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 2000, height: 800),
            insets: .zero
        )

        // available = (2000 - 30 * 2 * 3) / 3 = 606.67 >= 440, clamped to
        // the maximal line length 520, still 3 columns
        #expect(layout == LayoutResolver.Layout(colCount: 3, lineLength: 520))
    }

    /// Requested columns laid out with a minimal line length of `0`.
    struct ZeroMinimalLineLength: Sendable, CustomTestStringConvertible {
        let name: String
        let columnCount: Int
        let width: Double
        var pageMargins: Double = 1.0 // 30
        let expected: LayoutResolver.Layout

        var testDescription: String {
            name
        }
    }

    @Test("a minimal line length of 0 lays out the requested columns, unless the margins leave no room for the lines", arguments: [
        // (951 - 30 * 2 * 3) / 3 = 257
        ZeroMinimalLineLength(name: "short lines", columnCount: 3, width: 951, expected: .init(colCount: 3, lineLength: 257)),
        // (2000 - 30 * 2 * 2) / 2 = 940, capped at 740
        ZeroMinimalLineLength(name: "lines longer than the maximal line length", columnCount: 2, width: 2000, expected: .init(colCount: 2, lineLength: 740)),
        // 390 / 3 = 130 and 390 / 2 = 195 are narrower than the margins
        // 120 * 2, one column of 390 - 120 * 2 = 150 remains
        ZeroMinimalLineLength(name: "margins leaving no room for the lines", columnCount: 3, width: 390, pageMargins: 4.0, expected: .init(colCount: 1, lineLength: 150)),
    ])
    func paginatedRequestedColumnsWithZeroMinimalLineLength(_ example: ZeroMinimalLineLength) {
        let layout = resolver.layout(
            scroll: false,
            verticalText: false,
            columnCount: example.columnCount,
            optimalLineLength: 64, // 640
            minimalLineLength: 0,
            maximalLineLength: 74, // 740
            pageMargins: example.pageMargins,
            characterWidth: characterWidth,
            viewportSize: CGSize(width: example.width, height: 800)
        )

        #expect(layout == example.expected)
    }

    // MARK: - Zero Viewport

    /// A zero viewport, for example before the first layout of the view,
    /// gives empty lines instead of a crash or NaN.
    struct ZeroViewport: Sendable, CustomTestStringConvertible {
        let name: String
        var scroll: Bool = false
        var columnCount: Int?
        let expected: LayoutResolver.Layout

        var testDescription: String {
            name
        }
    }

    @Test("a zero viewport gives empty lines", arguments: [
        ZeroViewport(name: "scrolled", scroll: true, expected: .init(colCount: 1, lineLength: 0)),
        ZeroViewport(name: "automatic columns", expected: .init(colCount: 1, lineLength: 0)),
        // The margins leave no room for the lines of two columns.
        ZeroViewport(name: "two requested columns", columnCount: 2, expected: .init(colCount: 1, lineLength: 0)),
    ])
    func zeroViewport(_ test: ZeroViewport) {
        for verticalText in [false, true] {
            let layout = resolver.layout(
                scroll: test.scroll,
                verticalText: verticalText,
                columnCount: test.columnCount,
                optimalLineLength: 64, // 640
                minimalLineLength: 44, // 440
                maximalLineLength: 74, // 740
                pageMargins: 1.0,
                characterWidth: characterWidth,
                viewportSize: .zero,
                insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            )

            #expect(layout == test.expected, "verticalText: \(verticalText)")
        }
    }

    // MARK: - EPUBSettings Overload

    @Test func layoutWithEPUBSettings() {
        let layout = resolver.layout(
            settings: settings(),
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 1400, height: 900)
        )

        #expect(layout.colCount == 2)
        #expect(layout.lineLength == 640.0)
    }

    @Test func layoutWithEPUBSettingsUsesOptimalLineLengthAndPageMargins() {
        let layout = resolver.layout(
            settings: settings(optimalLineLength: 32, pageMargins: 2.0),
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 1400, height: 900)
        )

        // optimal: 32 * 10 = 320, margins: 30 * 2 = 60
        // floating colCount: (1400 - 381.8) / 320 = 3.2 -> 3
        // lineLength = (1400 - 60 * 2 * 3) / 3 = 346.67
        expectLayout(layout, .init(colCount: 3, lineLength: (1400 - 60 * 2 * 3) / 3))
    }

    @Test func layoutWithEPUBSettingsUsesMinimalAndMaximalLineLengths() {
        let layout = resolver.layout(
            settings: settings(
                columnCount: 2,
                maximalLineLength: 74, // 740
                minimalLineLength: 44 // 440
            ),
            characterWidth: characterWidth,
            viewportSize: CGSize(width: 900, height: 600)
        )

        // 2 columns: (900 - 120) / 2 = 390 < 440, falls back to 1 column
        // 1 column: 900 - 60 = 840, clamped to the maximal line length 740
        #expect(layout.colCount == 1)
        #expect(layout.lineLength == 740.0)
    }

    // MARK: - Default Line Lengths

    /// Layout with the default line lengths and settings, on the screens of
    /// the devices in points, with the width of a character at a 100% font
    /// size.
    struct DeviceLayout: Sendable, CustomTestStringConvertible {
        let name: String
        let width: Double
        var safeArea: Double = 0
        var scroll: Bool = false
        let colCount: Int
        let lineLength: Double

        var testDescription: String {
            scroll ? "\(name), scrolled" : name
        }
    }

    @Test("layout with the default settings", arguments: [
        // Two columns of the optimal line length need 2 × (65 × 8.89 + 2 × 30),
        // and the maximal line length is 80 × 8.89 = 711.38.
        DeviceLayout(name: "below the 2 columns threshold", width: 1275, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "at the 2 columns threshold", width: 1276, colCount: 2, lineLength: 578),
        DeviceLayout(name: "iPhone 17 Pro portrait", width: 402, colCount: 1, lineLength: 342),
        DeviceLayout(name: "iPhone 17 Pro landscape", width: 874, safeArea: 62, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "iPad mini portrait", width: 744, colCount: 1, lineLength: 684),
        DeviceLayout(name: "iPad mini landscape", width: 1133, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "iPad Air 11-inch portrait", width: 820, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "iPad Air 11-inch landscape", width: 1180, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "iPad Pro 11-inch landscape", width: 1210, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "iPad Air 13-inch landscape", width: 1366, colCount: 2, lineLength: 623),
        DeviceLayout(name: "iPad Pro 13-inch portrait", width: 1032, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "iPad Pro 13-inch landscape", width: 1376, colCount: 2, lineLength: 628),
        DeviceLayout(name: "iPhone 17 Pro portrait", width: 402, scroll: true, colCount: 1, lineLength: 342),
        DeviceLayout(name: "iPhone 17 Pro landscape", width: 874, safeArea: 62, scroll: true, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "iPad Air 11-inch landscape", width: 1180, scroll: true, colCount: 1, lineLength: 80 * iowanWidth),
        DeviceLayout(name: "iPad Pro 13-inch landscape", width: 1376, scroll: true, colCount: 1, lineLength: 80 * iowanWidth),
    ])
    func defaultLayout(device: DeviceLayout) {
        let layout = resolver.layout(
            settings: defaultSettings(preferences: EPUBPreferences(scroll: device.scroll)),
            characterWidth: iowanWidth,
            viewportSize: CGSize(width: device.width, height: 800),
            insets: UIEdgeInsets(top: 0, left: device.safeArea, bottom: 0, right: device.safeArea)
        )

        #expect(layout == LayoutResolver.Layout(colCount: device.colCount, lineLength: device.lineLength))
    }

    @Test("the default maximal line length limits the height of the vertical lines")
    func defaultLayoutWithVerticalText() {
        let layout = resolver.layout(
            settings: defaultSettings(preferences: EPUBPreferences(verticalText: true)),
            characterWidth: iowanWidth,
            viewportSize: CGSize(width: 820, height: 1180)
        )

        #expect(layout == LayoutResolver.Layout(colCount: 1, lineLength: 80 * iowanWidth))
    }

    @Test("the lines take all the available width with an infinite maximal line length", arguments: [false, true])
    func layoutWithInfiniteMaximalLineLength(scroll: Bool) {
        let layout = resolver.layout(
            settings: defaultSettings(preferences: EPUBPreferences(maximalLineLength: .infinity, scroll: scroll)),
            characterWidth: iowanWidth,
            viewportSize: CGSize(width: 1180, height: 800)
        )

        // 1180 - 2 × 30
        #expect(layout == LayoutResolver.Layout(colCount: 1, lineLength: 1120))
    }

    private func defaultSettings(
        preferences: EPUBPreferences = EPUBPreferences(),
        defaults: EPUBDefaults = EPUBDefaults()
    ) -> EPUBSettings {
        EPUBSettings(
            preferences: preferences,
            defaults: defaults,
            metadata: Metadata(title: "Test")
        )
    }

    private func settings(
        columnCount: Int? = nil,
        maximalLineLength: Double = .infinity,
        minimalLineLength: Double = 0,
        optimalLineLength: Double = 64, // 640
        pageMargins: Double = 1.0
    ) -> EPUBSettings {
        EPUBSettings(
            backgroundColor: nil,
            blendImages: false,
            columnCount: columnCount,
            darkenImages: nil,
            fit: .auto,
            fontFamily: nil,
            fontSize: 1.0,
            fontWeight: nil,
            fontWidth: nil,
            hyphens: nil,
            invertGaiji: false,
            invertImages: false,
            language: nil,
            letterSpacing: nil,
            ligatures: nil,
            lineHeight: nil,
            linkColor: nil,
            maximalLineLength: maximalLineLength,
            minimalLineLength: minimalLineLength,
            noRuby: false,
            offsetFirstPage: nil,
            optimalLineLength: optimalLineLength,
            pageMargins: pageMargins,
            paragraphIndent: nil,
            paragraphSpacing: nil,
            readingProgression: .ltr,
            scroll: false,
            spread: .auto,
            textAlign: nil,
            textColor: nil,
            textNormalization: false,
            verticalText: false,
            visitedColor: nil,
            wordSpacing: nil
        )
    }

    // MARK: - Character Width

    /// Layout with the default settings, with the width of a character at
    /// another font size than 100%.
    struct CharacterWidthLayout: Sendable, CustomTestStringConvertible {
        let name: String
        let characterWidth: Double
        let width: Double
        var scroll: Bool = false
        let colCount: Int
        let lineLength: Double

        var testDescription: String {
            scroll ? "\(name), scrolled" : name
        }
    }

    @Test("the line lengths follow the width of a character, but not the margins", arguments: [
        // Two columns of the optimal line length need 2 × (578 × scale + 2 × 30).
        // At 80%: 1044.8pt.
        CharacterWidthLayout(name: "80%, below the 2 columns threshold", characterWidth: iowanWidth * 0.8, width: 1044, colCount: 1, lineLength: 80 * iowanWidth * 0.8),
        CharacterWidthLayout(name: "80%, above the 2 columns threshold", characterWidth: iowanWidth * 0.8, width: 1045, colCount: 2, lineLength: 462.5),
        // At 120%: 1507.2pt.
        CharacterWidthLayout(name: "120%, below the 2 columns threshold", characterWidth: iowanWidth * 1.2, width: 1507, colCount: 1, lineLength: 80 * iowanWidth * 1.2),
        CharacterWidthLayout(name: "120%, above the 2 columns threshold", characterWidth: iowanWidth * 1.2, width: 1508, colCount: 2, lineLength: 694),
        // The margins stay 30pt.
        CharacterWidthLayout(name: "150%, iPhone 17 Pro portrait", characterWidth: iowanWidth * 1.5, width: 402, colCount: 1, lineLength: 342),
        CharacterWidthLayout(name: "200%, iPad mini landscape", characterWidth: iowanWidth * 2, width: 1133, colCount: 1, lineLength: 1073),
        CharacterWidthLayout(name: "200%, iPad mini landscape", characterWidth: iowanWidth * 2, width: 1133, scroll: true, colCount: 1, lineLength: 1073),
        // The maximal line length limits the scrolled lines.
        CharacterWidthLayout(name: "150%, iPad Air 13-inch landscape", characterWidth: iowanWidth * 1.5, width: 1366, scroll: true, colCount: 1, lineLength: 80 * iowanWidth * 1.5),
    ])
    func characterWidthLayout(_ test: CharacterWidthLayout) {
        let layout = resolver.layout(
            settings: defaultSettings(preferences: EPUBPreferences(scroll: test.scroll)),
            characterWidth: test.characterWidth,
            viewportSize: CGSize(width: test.width, height: 800)
        )

        expectLayout(layout, .init(colCount: test.colCount, lineLength: test.lineLength))
    }

    /// Two columns of (1000 - 4 × 30) / 2 = 440pt are requested, with the
    /// default minimal line length of 40 characters.
    @Test("the minimal line length of the requested columns follows the width of a character", arguments: [
        // 40 × 8.89 × 1.2 = 426.8pt.
        CharacterWidthLayout(name: "120%", characterWidth: iowanWidth * 1.2, width: 1000, colCount: 2, lineLength: 440),
        // 40 × 8.89 × 1.25 = 444.6pt, one column of 1000 - 2 × 30 = 940pt.
        CharacterWidthLayout(name: "125%", characterWidth: iowanWidth * 1.25, width: 1000, colCount: 1, lineLength: 940),
    ])
    func characterWidthMinimalLineLength(_ test: CharacterWidthLayout) {
        let layout = resolver.layout(
            settings: defaultSettings(
                preferences: EPUBPreferences(columnCount: 2, maximalLineLength: .infinity)
            ),
            characterWidth: test.characterWidth,
            viewportSize: CGSize(width: test.width, height: 800)
        )

        expectLayout(layout, .init(colCount: test.colCount, lineLength: test.lineLength))
    }

    /// One column is requested, with the default maximal line length of 80
    /// characters.
    @Test("the maximal line length of the requested columns follows the width of a character", arguments: [
        CharacterWidthLayout(name: "50%", characterWidth: iowanWidth * 0.5, width: 1366, colCount: 1, lineLength: 80 * iowanWidth * 0.5),
        // 80 × 8.89 × 2 = 1422.8pt is longer than 1366 - 2 × 30.
        CharacterWidthLayout(name: "200%", characterWidth: iowanWidth * 2, width: 1366, colCount: 1, lineLength: 1306),
    ])
    func characterWidthMaximalLineLength(_ test: CharacterWidthLayout) {
        let layout = resolver.layout(
            settings: defaultSettings(preferences: EPUBPreferences(columnCount: 1)),
            characterWidth: test.characterWidth,
            viewportSize: CGSize(width: test.width, height: 800)
        )

        expectLayout(layout, .init(colCount: test.colCount, lineLength: test.lineLength))
    }

    @Test("the margins don't follow the width of a character", arguments: [false, true])
    func characterWidthDoesNotScaleMargins(scroll: Bool) {
        let layout = resolver.layout(
            scroll: scroll,
            verticalText: false,
            columnCount: 2,
            optimalLineLength: 65,
            minimalLineLength: 0,
            maximalLineLength: .infinity,
            pageMargins: 1.5, // 45
            characterWidth: iowanWidth * 2,
            viewportSize: CGSize(width: 1000, height: 800),
            insets: .zero
        )

        if scroll {
            // 1000 - 2 × 45
            #expect(layout == LayoutResolver.Layout(colCount: 1, lineLength: 910))
        } else {
            // (1000 - 4 × 45) / 2
            #expect(layout == LayoutResolver.Layout(colCount: 2, lineLength: 410))
        }
    }

    @Test("the maximal line length of the vertical lines follows the width of a character")
    func characterWidthWithVerticalText() {
        let layout = resolver.layout(
            settings: defaultSettings(preferences: EPUBPreferences(scroll: true, verticalText: true)),
            characterWidth: iowanWidth * 1.5,
            viewportSize: CGSize(width: 820, height: 1180)
        )

        // 80 × 8.89 × 1.5 = 1067.08, below 1180 - 2 × 30
        expectLayout(layout, .init(colCount: 1, lineLength: 80 * iowanWidth * 1.5))
    }

    /// Layout with the default line lengths around the vertical hinge of an
    /// iPhone Duo unfolded in landscape (951 x 669pt, 40pt band).
    @Suite("With a vertical hinge") struct Hinge {
        let resolver = LayoutResolver()

        struct HingeLayout: Sendable, CustomTestStringConvertible {
            let name: String
            var scroll: Bool = false
            var verticalText: Bool = false
            var columnCount: Int?
            /// No minimum by default, to show the layout of the requested
            /// columns.
            var minimalLineLength: Double = 0
            var pageMargins: Double = 1.0
            var characterWidth: Double = iowanWidth
            var width: Double = 951
            var hingeWidth: Double? = 40
            let expected: LayoutResolver.Layout

            var testDescription: String {
                name
            }
        }

        @Test("each side of the hinge gets its own column, in auto mode only", arguments: [
            // Each 475.5pt side holds one column: 475.5 - 2 × 30.
            HingeLayout(name: "two columns", expected: .init(colCount: 2, lineLength: 415.5)),
            HingeLayout(name: "one column without a hinge", hingeWidth: nil, expected: .init(colCount: 1, lineLength: 80 * iowanWidth)),
            HingeLayout(name: "a hinge line without a band", hingeWidth: 0, expected: .init(colCount: 2, lineLength: 415.5)),
            // The lines are shorter than the optimal one at 100% already.
            HingeLayout(name: "a larger font", characterWidth: iowanWidth * 2, expected: .init(colCount: 2, lineLength: 415.5)),
            HingeLayout(name: "a smaller font, limited by the maximal line length", characterWidth: iowanWidth * 0.5, expected: .init(colCount: 2, lineLength: 80 * iowanWidth * 0.5)),
            // Without the hinge, 3 columns with the middle one on the hinge.
            HingeLayout(name: "instead of three columns", characterWidth: iowanWidth * 0.4, expected: .init(colCount: 2, lineLength: 80 * iowanWidth * 0.4)),
            // Without the hinge, 4 columns. The pagination scripts only fill
            // the last screen with two columns per screen.
            HingeLayout(name: "instead of four columns", characterWidth: iowanWidth * 0.3, expected: .init(colCount: 2, lineLength: 80 * iowanWidth * 0.3)),
            // Margins of half the band, 20pt.
            HingeLayout(name: "no page margins", pageMargins: 0, expected: .init(colCount: 2, lineLength: 435.5)),
            HingeLayout(name: "larger page margins", pageMargins: 2, expected: .init(colCount: 2, lineLength: 355.5)),
            // 48 × 8.89 = 426.8 is above 415.5, but it only applies to the
            // requested columns.
            HingeLayout(name: "a minimal line length", minimalLineLength: 48, expected: .init(colCount: 2, lineLength: 415.5)),
            // 350 - 20 is below the 356pt minimal side width.
            HingeLayout(name: "sides too narrow", width: 700, expected: .init(colCount: 1, lineLength: 640)),
            // 376 - 20 is the 356pt minimal side width: 376 - 2 × 30.
            HingeLayout(name: "sides at the minimal side width", width: 752, expected: .init(colCount: 2, lineLength: 316)),
            // 375 - 20 is 1pt below the minimal side width: 750 - 2 × 30.
            HingeLayout(name: "sides 1pt narrower than the minimal side width", width: 750, expected: .init(colCount: 1, lineLength: 690)),
            HingeLayout(name: "already two columns", width: 1366, expected: .init(colCount: 2, lineLength: 623)),
            HingeLayout(name: "one requested column", columnCount: 1, expected: .init(colCount: 1, lineLength: 80 * iowanWidth)),
            HingeLayout(name: "three requested columns", columnCount: 3, expected: .init(colCount: 3, lineLength: 257)),
            HingeLayout(name: "scroll mode", scroll: true, expected: .init(colCount: 1, lineLength: 80 * iowanWidth)),
            // Not reachable, vertical text is always scrolled.
            HingeLayout(name: "vertical text", verticalText: true, expected: .init(colCount: 1, lineLength: 80 * iowanWidth)),
        ])
        func layoutAroundHinge(_ test: HingeLayout) {
            let layout = resolver.layout(
                scroll: test.scroll,
                verticalText: test.verticalText,
                columnCount: test.columnCount,
                optimalLineLength: 65,
                minimalLineLength: test.minimalLineLength,
                maximalLineLength: 80,
                pageMargins: test.pageMargins,
                characterWidth: test.characterWidth,
                viewportSize: CGSize(width: test.width, height: 669),
                hingeWidth: test.hingeWidth
            )

            expectLayout(layout, test.expected)
        }

        struct HingeMargins: Sendable, CustomTestStringConvertible {
            let pageMargins: Double
            let characterWidth: Double
            let insets: UIEdgeInsets

            var testDescription: String {
                "page margins \(pageMargins), character width \(String(format: "%.2f", characterWidth)), insets \(insets.left) and \(insets.right)"
            }
        }

        @Test("no text is on the hinge", arguments: [0.0, 0.5, 1.0, 2.0, 4.0].flatMap { pageMargins in
            [iowanWidth * 0.5, iowanWidth, iowanWidth * 2].flatMap { characterWidth in
                [UIEdgeInsets.zero, UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 84), UIEdgeInsets(top: 0, left: 62, bottom: 0, right: 62)].map { insets in
                    HingeMargins(pageMargins: pageMargins, characterWidth: characterWidth, insets: insets)
                }
            }
        })
        func noTextOnHinge(_ test: HingeMargins) {
            let layout = resolver.layout(
                scroll: false,
                verticalText: false,
                columnCount: nil,
                optimalLineLength: 65,
                minimalLineLength: 0,
                maximalLineLength: 80,
                pageMargins: test.pageMargins,
                characterWidth: test.characterWidth,
                viewportSize: CGSize(width: 951, height: 669),
                insets: test.insets,
                hingeWidth: 40
            )

            #expect(layout.colCount == 2)
            #expect(layout.lineLength > 0)
            // The lines are centered in their column, half of the viewport.
            let sideMargin = (951 / 2 - layout.lineLength) / 2
            #expect(sideMargin >= 20)
            #expect(sideMargin >= max(test.insets.left, test.insets.right))
        }

        struct Division: Sendable, CustomTestStringConvertible {
            let name: String
            var bounds = CGRect(x: 0, y: 0, width: 951, height: 669)
            let divisions: [CGRect]
            let expected: Double?

            var testDescription: String {
                name
            }
        }

        @Test("only a full height division centered in the view is a hinge", arguments: [
            Division(name: "unfolded in landscape", divisions: [CGRect(x: 455.5, y: 0, width: 40, height: 669)], expected: 40),
            Division(name: "a hinge line without a band", divisions: [CGRect(x: 475.5, y: 0, width: 0, height: 669)], expected: 0),
            Division(name: "centered within the tolerance", divisions: [CGRect(x: 457, y: 0, width: 40, height: 669)], expected: 40),
            Division(name: "off center", divisions: [CGRect(x: 460, y: 0, width: 40, height: 669)], expected: nil),
            Division(name: "folded", divisions: [], expected: nil),
            Division(
                name: "unfolded in portrait",
                bounds: CGRect(x: 0, y: 0, width: 669, height: 951),
                divisions: [CGRect(x: 0, y: 455.5, width: 669, height: 40)],
                expected: nil
            ),
            Division(
                name: "the landscape hinge in portrait bounds, during a rotation",
                bounds: CGRect(x: 0, y: 0, width: 669, height: 951),
                divisions: [CGRect(x: 455.5, y: 0, width: 40, height: 669)],
                expected: nil
            ),
            Division(
                name: "the portrait hinge in landscape bounds, during a rotation",
                divisions: [CGRect(x: 0, y: 455.5, width: 669, height: 40)],
                expected: nil
            ),
            Division(
                name: "in a narrower window",
                bounds: CGRect(x: 0, y: 0, width: 600, height: 669),
                divisions: [CGRect(x: 455.5, y: 0, width: 40, height: 669)],
                expected: nil
            ),
            Division(name: "not the full height", divisions: [CGRect(x: 455.5, y: 100, width: 40, height: 569)], expected: nil),
            Division(name: "wider than half the view", divisions: [CGRect(x: 200, y: 0, width: 551, height: 669)], expected: nil),
            Division(
                name: "among other divisions",
                divisions: [CGRect(x: 0, y: 300, width: 951, height: 40), CGRect(x: 455.5, y: 0, width: 40, height: 669)],
                expected: 40
            ),
            Division(name: "an empty view", bounds: .zero, divisions: [.zero], expected: nil),
        ])
        func verticalHingeWidth(_ test: Division) {
            #expect(LayoutResolver.verticalHingeWidth(divisions: test.divisions, in: test.bounds) == test.expected)
        }
    }

    /// Layout with the default line lengths, with large margins or line
    /// lengths.
    @Suite("With extreme settings") struct Extremes {
        let resolver = LayoutResolver()

        struct ExtremeLayout: Sendable, CustomTestStringConvertible {
            let name: String
            var scroll: Bool = false
            var columnCount: Int?
            var minimalLineLength: Double = 0
            var maximalLineLength: Double = .infinity
            let pageMargins: Double
            var characterWidth: Double = iowanWidth
            let width: Double
            let expected: LayoutResolver.Layout

            var testDescription: String {
                name
            }
        }

        @Test("resolves extreme settings", arguments: [
            // The maximal line length 40 × 8.89 × 0.4 = 142.28 is below the
            // 2 × 120pt margins.
            ExtremeLayout(name: "a maximal line length shorter than the margins, scrolled", scroll: true, maximalLineLength: 40, pageMargins: 4, characterWidth: iowanWidth * 0.4, width: 1000, expected: .init(colCount: 1, lineLength: 40 * iowanWidth * 0.4)),
            ExtremeLayout(name: "a maximal line length shorter than the margins, one requested column", columnCount: 1, maximalLineLength: 40, pageMargins: 4, characterWidth: iowanWidth * 0.4, width: 1000, expected: .init(colCount: 1, lineLength: 40 * iowanWidth * 0.4)),
            // The 120pt margins take each 195pt column, one column remains.
            ExtremeLayout(name: "margins wider than the requested columns", columnCount: 2, pageMargins: 4, width: 390, expected: .init(colCount: 1, lineLength: 150)),
            ExtremeLayout(name: "margins wider than the requested columns, with a minimal line length", columnCount: 2, minimalLineLength: 40, pageMargins: 4, width: 390, expected: .init(colCount: 1, lineLength: 150)),
            ExtremeLayout(name: "margins wider than the viewport, scrolled", scroll: true, pageMargins: 4, width: 200, expected: .init(colCount: 1, lineLength: 0)),
            ExtremeLayout(name: "margins wider than the viewport, auto", pageMargins: 4, width: 200, expected: .init(colCount: 1, lineLength: 0)),
            // Two columns of (600 - 4 × 90) / 2 = 120pt are below the
            // 355.69pt minimal line length, even though three columns have
            // less room.
            ExtremeLayout(name: "the minimal line length of the requested columns is kept when reducing them", columnCount: 3, minimalLineLength: 40, pageMargins: 3, width: 600, expected: .init(colCount: 1, lineLength: 420)),
            // The single column of 600 - 2 × 120 = 360pt is limited by the
            // maximal line length 40 × 8.89 × 0.4 = 142.28.
            ExtremeLayout(name: "the maximal line length of the requested columns is kept when reducing them", columnCount: 3, minimalLineLength: 40, maximalLineLength: 40, pageMargins: 4, characterWidth: iowanWidth * 0.4, width: 600, expected: .init(colCount: 1, lineLength: 40 * iowanWidth * 0.4)),
        ])
        func extremeLayout(_ test: ExtremeLayout) {
            let layout = resolver.layout(
                scroll: test.scroll,
                verticalText: false,
                columnCount: test.columnCount,
                optimalLineLength: 65,
                minimalLineLength: test.minimalLineLength,
                maximalLineLength: test.maximalLineLength,
                pageMargins: test.pageMargins,
                characterWidth: test.characterWidth,
                viewportSize: CGSize(width: test.width, height: 800)
            )

            expectLayout(layout, test.expected)
        }

        struct Mode: Sendable, CustomTestStringConvertible {
            let name: String
            var scroll: Bool = false
            var columnCount: Int?
            var hingeWidth: Double?

            var testDescription: String {
                name
            }
        }

        @Test("the lines fit in the viewport, and are only empty in a single column", arguments: [
            Mode(name: "scrolled", scroll: true),
            Mode(name: "auto"),
            Mode(name: "auto around a hinge", hingeWidth: 40),
            Mode(name: "one requested column", columnCount: 1),
            Mode(name: "two requested columns", columnCount: 2),
            Mode(name: "three requested columns", columnCount: 3),
        ], [1.0, 100, 390, 951, 2000])
        func linesFitInViewport(mode: Mode, width: Double) {
            // The bounds of the preferences editor, and safe area insets
            // larger than the margins. The viewport is square, so the lines
            // have the same room with vertical text.
            for verticalText in [false, true] {
                for pageMargins in [0.0, 4.0] {
                    for characterWidth in [iowanWidth * 0.1, iowanWidth * 5] {
                        for lineLength in [nil, 30.0, 130.0] {
                            for inset in [0.0, 300.0] {
                                let layout = resolver.layout(
                                    scroll: mode.scroll,
                                    verticalText: verticalText,
                                    columnCount: mode.columnCount,
                                    optimalLineLength: lineLength ?? 65,
                                    minimalLineLength: lineLength ?? 0,
                                    maximalLineLength: lineLength ?? .infinity,
                                    pageMargins: pageMargins,
                                    characterWidth: characterWidth,
                                    viewportSize: CGSize(width: width, height: width),
                                    insets: UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset),
                                    hingeWidth: mode.hingeWidth
                                )

                                let context: Comment = "verticalText: \(verticalText), pageMargins: \(pageMargins), characterWidth: \(characterWidth), lineLength: \(String(describing: lineLength)), inset: \(inset)"
                                #expect(layout.colCount >= 1, context)
                                #expect(layout.lineLength >= 0, context)
                                #expect(layout.colCount == 1 || layout.lineLength > 0, context)
                                #expect(layout.lineLength * Double(layout.colCount) <= width + 0.0001, context)
                            }
                        }
                    }
                }
            }
        }
    }
}
