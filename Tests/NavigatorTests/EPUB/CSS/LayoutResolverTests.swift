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

struct LayoutResolverTests {
    /// Fixture lengths, different from the default ones, which are tested
    /// below with `LayoutResolver()`.
    let resolver = LayoutResolver(
        baseMinMargins: 30.0,
        baseOptimalLineLength: 640.0,
        baseMinLineLength: 440.0,
        baseMaxLineLength: 740.0
    )

    // MARK: - Scrolled Layout

    @Test func scrolledHorizontalLayout() {
        let layout = resolver.layout(
            scroll: true,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: nil,
            pageMargins: 1.0,
            fontScale: 1.0,
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
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: nil,
            pageMargins: 1.0,
            fontScale: 1.0,
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
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: 0.8, // 740 * 0.8 = 592
            pageMargins: 1.0,
            fontScale: 1.0,
            viewportSize: CGSize(width: 1000, height: 800),
            insets: .zero
        )

        #expect(layout.colCount == 1)
        // available = 1000 - 60 = 940, clamped to max 592
        #expect(layout.lineLength == 592.0)
    }

    @Test func scrolledLayoutWithSafeAreaInsets() {
        let layout = resolver.layout(
            scroll: true,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: nil,
            pageMargins: 1.0, // 30
            fontScale: 1.0,
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
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: nil,
            pageMargins: 1.0, // 30
            fontScale: 1.0,
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
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: nil,
            pageMargins: 1.0,
            fontScale: 1.0,
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
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: nil,
            pageMargins: 1.0,
            fontScale: 1.0,
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
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: 0.8, // 740 * 0.8 = 592
            pageMargins: 1.0,
            fontScale: 1.0,
            viewportSize: CGSize(width: 1400, height: 900),
            insets: .zero
        )

        #expect(layout.colCount == 2)
        // available = (1400 - 120) / 2 = 640, clamped to max 592
        #expect(layout.lineLength == 592.0)
    }

    // MARK: - Paginated Layout N Columns

    @Test func paginatedRequestedColumnsHonoredWhenFitting() {
        let layout = resolver.layout(
            scroll: false,
            verticalText: false,
            columnCount: 2,
            optimalLineLength: 1.0,
            minimalLineLength: 1.0, // 440
            maximalLineLength: nil,
            pageMargins: 1.0, // 30
            fontScale: 1.0,
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
            optimalLineLength: 1.0,
            minimalLineLength: 1.0, // 440
            maximalLineLength: nil,
            pageMargins: 1.0, // 30
            fontScale: 1.0,
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
            optimalLineLength: 1.0,
            minimalLineLength: 1.0, // 440
            maximalLineLength: 0.7, // 518
            pageMargins: 1.0, // 30
            fontScale: 1.0,
            viewportSize: CGSize(width: 2000, height: 800),
            insets: .zero
        )

        // available = (2000 - 30 * 2 * 3) / 3 = 606.67 >= 440, clamped to
        // the maximal line length 518, still 3 columns
        #expect(layout == LayoutResolver.Layout(colCount: 3, lineLength: 518))
    }

    // MARK: - Zero Viewport

    /// A zero viewport, for example before the first layout of the view,
    /// gives empty lines instead of a crash or NaN.
    @Test(arguments: [
        (scroll: true, columnCount: nil, expected: LayoutResolver.Layout(colCount: 1, lineLength: 0)),
        (scroll: false, columnCount: nil, expected: LayoutResolver.Layout(colCount: 1, lineLength: 0)),
        (scroll: false, columnCount: 2, expected: LayoutResolver.Layout(colCount: 2, lineLength: 0)),
    ] as [(scroll: Bool, columnCount: Int?, expected: LayoutResolver.Layout)])
    func zeroViewport(scroll: Bool, columnCount: Int?, expected: LayoutResolver.Layout) {
        for verticalText in [false, true] {
            let layout = resolver.layout(
                scroll: scroll,
                verticalText: verticalText,
                columnCount: columnCount,
                optimalLineLength: 1.0,
                minimalLineLength: 1.0,
                maximalLineLength: 1.0,
                pageMargins: 1.0,
                fontScale: 1.0,
                viewportSize: .zero,
                insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            )

            #expect(layout == expected, "verticalText: \(verticalText)")
        }
    }

    // MARK: - EPUBSettings Overload

    @Test func layoutWithEPUBSettings() {
        let layout = resolver.layout(
            settings: settings(),
            fontScale: 1.0,
            viewportSize: CGSize(width: 1400, height: 900)
        )

        #expect(layout.colCount == 2)
        #expect(layout.lineLength == 640.0)
    }

    @Test func layoutWithEPUBSettingsUsesOptimalLineLengthAndPageMargins() {
        let layout = resolver.layout(
            settings: settings(optimalLineLength: 0.5, pageMargins: 2.0),
            fontScale: 1.0,
            viewportSize: CGSize(width: 1400, height: 900)
        )

        // optimal: 640 * 0.5 = 320, margins: 30 * 2 = 60
        // floating colCount: (1400 - 381.8) / 320 = 3.2 -> 3
        // lineLength = (1400 - 60 * 2 * 3) / 3 = 346.67
        #expect(layout.colCount == 3)
        #expect(abs(layout.lineLength - 346.667) < 0.001)
    }

    @Test func layoutWithEPUBSettingsUsesMinimalAndMaximalLineLengths() {
        let layout = resolver.layout(
            settings: settings(
                columnCount: 2,
                maximalLineLength: 1.0, // 740
                minimalLineLength: 1.0 // 440
            ),
            fontScale: 1.0,
            viewportSize: CGSize(width: 900, height: 600)
        )

        // 2 columns: (900 - 120) / 2 = 390 < 440, falls back to 1 column
        // 1 column: 900 - 60 = 840, clamped to the maximal line length 740
        #expect(layout.colCount == 1)
        #expect(layout.lineLength == 740.0)
    }

    // MARK: - Default Line Lengths

    /// Layout with the default line lengths and settings, on the screens of
    /// the devices in points.
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
        // Two columns of the optimal line length need 2 × (578 + 2 × 30).
        DeviceLayout(name: "below the 2 columns threshold", width: 1275, colCount: 1, lineLength: 712),
        DeviceLayout(name: "at the 2 columns threshold", width: 1276, colCount: 2, lineLength: 578),
        DeviceLayout(name: "iPhone 17 Pro portrait", width: 402, colCount: 1, lineLength: 342),
        DeviceLayout(name: "iPhone 17 Pro landscape", width: 874, safeArea: 62, colCount: 1, lineLength: 712),
        DeviceLayout(name: "iPad mini portrait", width: 744, colCount: 1, lineLength: 684),
        DeviceLayout(name: "iPad mini landscape", width: 1133, colCount: 1, lineLength: 712),
        DeviceLayout(name: "iPad Air 11-inch portrait", width: 820, colCount: 1, lineLength: 712),
        DeviceLayout(name: "iPad Air 11-inch landscape", width: 1180, colCount: 1, lineLength: 712),
        DeviceLayout(name: "iPad Pro 11-inch landscape", width: 1210, colCount: 1, lineLength: 712),
        DeviceLayout(name: "iPad Air 13-inch landscape", width: 1366, colCount: 2, lineLength: 623),
        DeviceLayout(name: "iPad Pro 13-inch portrait", width: 1032, colCount: 1, lineLength: 712),
        DeviceLayout(name: "iPad Pro 13-inch landscape", width: 1376, colCount: 2, lineLength: 628),
        DeviceLayout(name: "iPhone 17 Pro portrait", width: 402, scroll: true, colCount: 1, lineLength: 342),
        DeviceLayout(name: "iPhone 17 Pro landscape", width: 874, safeArea: 62, scroll: true, colCount: 1, lineLength: 712),
        DeviceLayout(name: "iPad Air 11-inch landscape", width: 1180, scroll: true, colCount: 1, lineLength: 712),
        DeviceLayout(name: "iPad Pro 13-inch landscape", width: 1376, scroll: true, colCount: 1, lineLength: 712),
    ])
    func defaultLayout(device: DeviceLayout) {
        let layout = LayoutResolver().layout(
            settings: defaultSettings(preferences: EPUBPreferences(scroll: device.scroll)),
            fontScale: 1.0,
            viewportSize: CGSize(width: device.width, height: 800),
            insets: UIEdgeInsets(top: 0, left: device.safeArea, bottom: 0, right: device.safeArea)
        )

        #expect(layout == LayoutResolver.Layout(colCount: device.colCount, lineLength: device.lineLength))
    }

    @Test("the default maximal line length limits the height of the vertical lines")
    func defaultLayoutWithVerticalText() {
        let layout = LayoutResolver().layout(
            settings: defaultSettings(preferences: EPUBPreferences(verticalText: true)),
            fontScale: 1.0,
            viewportSize: CGSize(width: 820, height: 1180)
        )

        #expect(layout == LayoutResolver.Layout(colCount: 1, lineLength: 712))
    }

    @Test("the lines take all the available width without a default maximal line length", arguments: [false, true])
    func defaultLayoutWithoutMaximalLineLength(scroll: Bool) {
        let layout = LayoutResolver().layout(
            settings: defaultSettings(
                preferences: EPUBPreferences(scroll: scroll),
                defaults: EPUBDefaults(maximalLineLength: nil)
            ),
            fontScale: 1.0,
            viewportSize: CGSize(width: 1180, height: 800)
        )

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
        maximalLineLength: Double? = nil,
        minimalLineLength: Double? = nil,
        optimalLineLength: Double = 1.0,
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

    // MARK: - Font Scale

    /// Layout with the default settings at a font size.
    struct FontScaleLayout: Sendable, CustomTestStringConvertible {
        let name: String
        let fontScale: Double
        let width: Double
        var scroll: Bool = false
        let colCount: Int
        let lineLength: Double

        var testDescription: String {
            "\(name) at \(Int((fontScale * 100).rounded()))%" + (scroll ? ", scrolled" : "")
        }
    }

    @Test("the line lengths follow the font size, but not the margins", arguments: [
        // Two columns of the optimal line length need 2 × (578 × scale + 2 × 30).
        // At 80%: 1044.8pt, the maximal line length is 569.6pt.
        FontScaleLayout(name: "below the 2 columns threshold", fontScale: 0.8, width: 1044, colCount: 1, lineLength: 569.6),
        FontScaleLayout(name: "above the 2 columns threshold", fontScale: 0.8, width: 1045, colCount: 2, lineLength: 462.5),
        FontScaleLayout(name: "iPad mini landscape", fontScale: 0.8, width: 1133, colCount: 2, lineLength: 506.5),
        FontScaleLayout(name: "iPad Air 13-inch landscape", fontScale: 0.8, width: 1366, colCount: 2, lineLength: 569.6),
        // At 100%: 1276pt, the maximal line length is 712pt.
        FontScaleLayout(name: "below the 2 columns threshold", fontScale: 1.0, width: 1275, colCount: 1, lineLength: 712),
        FontScaleLayout(name: "at the 2 columns threshold", fontScale: 1.0, width: 1276, colCount: 2, lineLength: 578),
        // At 120%: 1507.2pt, the maximal line length is 854.4pt.
        FontScaleLayout(name: "iPad Air 13-inch landscape", fontScale: 1.2, width: 1366, colCount: 1, lineLength: 854.4),
        FontScaleLayout(name: "below the 2 columns threshold", fontScale: 1.2, width: 1507, colCount: 1, lineLength: 854.4),
        FontScaleLayout(name: "above the 2 columns threshold", fontScale: 1.2, width: 1508, colCount: 2, lineLength: 694),
        // At 150%, the maximal line length is 1068pt.
        FontScaleLayout(name: "iPad Air 13-inch landscape", fontScale: 1.5, width: 1366, colCount: 1, lineLength: 1068),
        FontScaleLayout(name: "iPad mini landscape", fontScale: 1.5, width: 1133, colCount: 1, lineLength: 1068),
        // The margins stay 30pt.
        FontScaleLayout(name: "iPhone 17 Pro portrait", fontScale: 1.5, width: 402, colCount: 1, lineLength: 342),
        FontScaleLayout(name: "iPad mini landscape", fontScale: 2.0, width: 1133, colCount: 1, lineLength: 1073),
        // The maximal line length limits the scrolled lines.
        FontScaleLayout(name: "iPad Air 13-inch landscape", fontScale: 0.8, width: 1366, scroll: true, colCount: 1, lineLength: 569.6),
        FontScaleLayout(name: "iPad Air 13-inch landscape", fontScale: 1.0, width: 1366, scroll: true, colCount: 1, lineLength: 712),
        FontScaleLayout(name: "iPad Air 13-inch landscape", fontScale: 1.5, width: 1366, scroll: true, colCount: 1, lineLength: 1068),
        FontScaleLayout(name: "iPad mini landscape", fontScale: 2.0, width: 1133, scroll: true, colCount: 1, lineLength: 1073),
        FontScaleLayout(name: "iPhone 17 Pro portrait", fontScale: 1.5, width: 402, scroll: true, colCount: 1, lineLength: 342),
    ])
    func fontScaleLayout(_ test: FontScaleLayout) {
        let layout = LayoutResolver().layout(
            settings: defaultSettings(preferences: EPUBPreferences(scroll: test.scroll)),
            fontScale: test.fontScale,
            viewportSize: CGSize(width: test.width, height: 800)
        )

        #expect(layout.colCount == test.colCount)
        #expect(abs(layout.lineLength - test.lineLength) < 0.001)
    }

    /// Two columns of (1000 - 4 × 30) / 2 = 440pt are requested, with the
    /// minimal line length of 356pt at 100%.
    @Test("the minimal line length of the requested columns follows the font size", arguments: [
        FontScaleLayout(name: "2 requested columns", fontScale: 1.0, width: 1000, colCount: 2, lineLength: 440),
        FontScaleLayout(name: "2 requested columns", fontScale: 1.2, width: 1000, colCount: 2, lineLength: 440),
        // 356 × 1.25 = 445pt, one column of 1000 - 2 × 30 = 940pt.
        FontScaleLayout(name: "2 requested columns", fontScale: 1.25, width: 1000, colCount: 1, lineLength: 940),
    ])
    func fontScaleMinimalLineLength(_ test: FontScaleLayout) {
        let layout = LayoutResolver().layout(
            settings: defaultSettings(
                preferences: EPUBPreferences(columnCount: 2, maximalLineLength: 2.0, minimalLineLength: 1.0)
            ),
            fontScale: test.fontScale,
            viewportSize: CGSize(width: test.width, height: 800)
        )

        #expect(layout == LayoutResolver.Layout(colCount: test.colCount, lineLength: test.lineLength))
    }

    /// One column is requested, limited by the maximal line length of 712pt
    /// at 100%.
    @Test("the maximal line length of the requested columns follows the font size", arguments: [
        FontScaleLayout(name: "1 requested column", fontScale: 0.5, width: 1366, colCount: 1, lineLength: 356),
        FontScaleLayout(name: "1 requested column", fontScale: 1.0, width: 1366, colCount: 1, lineLength: 712),
        FontScaleLayout(name: "1 requested column", fontScale: 1.5, width: 1366, colCount: 1, lineLength: 1068),
        FontScaleLayout(name: "1 requested column", fontScale: 2.0, width: 1366, colCount: 1, lineLength: 1306),
    ])
    func fontScaleMaximalLineLength(_ test: FontScaleLayout) {
        let layout = LayoutResolver().layout(
            settings: defaultSettings(preferences: EPUBPreferences(columnCount: 1)),
            fontScale: test.fontScale,
            viewportSize: CGSize(width: test.width, height: 800)
        )

        #expect(layout == LayoutResolver.Layout(colCount: test.colCount, lineLength: test.lineLength))
    }

    @Test("the margins don't follow the font size", arguments: [false, true])
    func fontScaleDoesNotScaleMargins(scroll: Bool) {
        let layout = LayoutResolver().layout(
            scroll: scroll,
            verticalText: false,
            columnCount: 2,
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: nil,
            pageMargins: 1.5, // 45
            fontScale: 2.0,
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

    @Test("the maximal line length of the vertical lines follows the font size")
    func fontScaleWithVerticalText() {
        let layout = LayoutResolver().layout(
            settings: defaultSettings(preferences: EPUBPreferences(scroll: true, verticalText: true)),
            fontScale: 1.5,
            viewportSize: CGSize(width: 820, height: 1180)
        )

        // 712 × 1.5, below 1180 - 2 × 30
        #expect(layout == LayoutResolver.Layout(colCount: 1, lineLength: 1068))
    }

    /// Layout with the default line lengths around the vertical hinge of an
    /// iPhone Duo unfolded in landscape (951 x 669pt, 40pt band).
    @Suite("With a vertical hinge") struct Hinge {
        struct HingeLayout: Sendable, CustomTestStringConvertible {
            let name: String
            var scroll: Bool = false
            var verticalText: Bool = false
            var columnCount: Int?
            var minimalLineLength: Double?
            var pageMargins: Double = 1.0
            var fontScale: Double = 1.0
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
            HingeLayout(name: "one column without a hinge", hingeWidth: nil, expected: .init(colCount: 1, lineLength: 712)),
            HingeLayout(name: "a hinge line without a band", hingeWidth: 0, expected: .init(colCount: 2, lineLength: 415.5)),
            // The lines are shorter than the optimal one at 100% already.
            HingeLayout(name: "a larger font", fontScale: 2.0, expected: .init(colCount: 2, lineLength: 415.5)),
            HingeLayout(name: "a smaller font, limited by the maximal line length", fontScale: 0.5, expected: .init(colCount: 2, lineLength: 356)),
            // Without the hinge, 3 columns with the middle one on the hinge.
            HingeLayout(name: "instead of three columns", fontScale: 0.4, expected: .init(colCount: 2, lineLength: 284.8)),
            // Without the hinge, 4 columns. The pagination scripts only fill
            // the last screen with two columns per screen.
            HingeLayout(name: "instead of four columns", fontScale: 0.3, expected: .init(colCount: 2, lineLength: 213.6)),
            // Margins of half the band, 20pt.
            HingeLayout(name: "no page margins", pageMargins: 0, expected: .init(colCount: 2, lineLength: 435.5)),
            HingeLayout(name: "larger page margins", pageMargins: 2, expected: .init(colCount: 2, lineLength: 355.5)),
            // 356 × 1.2 is above 415.5, but it only applies to the requested columns.
            HingeLayout(name: "a minimal line length", minimalLineLength: 1.2, expected: .init(colCount: 2, lineLength: 415.5)),
            // 350 - 20 is below the 356pt base minimal line length.
            HingeLayout(name: "sides too narrow", width: 700, expected: .init(colCount: 1, lineLength: 640)),
            HingeLayout(name: "already two columns", width: 1366, expected: .init(colCount: 2, lineLength: 623)),
            HingeLayout(name: "one requested column", columnCount: 1, expected: .init(colCount: 1, lineLength: 712)),
            HingeLayout(name: "three requested columns", columnCount: 3, expected: .init(colCount: 3, lineLength: 257)),
            HingeLayout(name: "scroll mode", scroll: true, expected: .init(colCount: 1, lineLength: 712)),
            // Not reachable, vertical text is always scrolled.
            HingeLayout(name: "vertical text", verticalText: true, expected: .init(colCount: 1, lineLength: 712)),
        ])
        func layoutAroundHinge(_ test: HingeLayout) {
            let layout = LayoutResolver().layout(
                scroll: test.scroll,
                verticalText: test.verticalText,
                columnCount: test.columnCount,
                optimalLineLength: 1.0,
                minimalLineLength: test.minimalLineLength,
                maximalLineLength: 1.0,
                pageMargins: test.pageMargins,
                fontScale: test.fontScale,
                viewportSize: CGSize(width: test.width, height: 669),
                hingeWidth: test.hingeWidth
            )

            #expect(layout.colCount == test.expected.colCount)
            #expect(abs(layout.lineLength - test.expected.lineLength) < 0.0001)
        }

        struct HingeMargins: Sendable, CustomTestStringConvertible {
            let pageMargins: Double
            let fontScale: Double
            let insets: UIEdgeInsets

            var testDescription: String {
                "page margins \(pageMargins), font scale \(fontScale), insets \(insets.left) and \(insets.right)"
            }
        }

        @Test("no text is on the hinge", arguments: [0.0, 0.5, 1.0, 2.0, 4.0].flatMap { pageMargins in
            [0.5, 1.0, 2.0].flatMap { fontScale in
                [UIEdgeInsets.zero, UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 84), UIEdgeInsets(top: 0, left: 62, bottom: 0, right: 62)].map { insets in
                    HingeMargins(pageMargins: pageMargins, fontScale: fontScale, insets: insets)
                }
            }
        })
        func noTextOnHinge(_ test: HingeMargins) {
            let layout = LayoutResolver().layout(
                scroll: false,
                verticalText: false,
                columnCount: nil,
                optimalLineLength: 1.0,
                minimalLineLength: nil,
                maximalLineLength: 1.0,
                pageMargins: test.pageMargins,
                fontScale: test.fontScale,
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
}
