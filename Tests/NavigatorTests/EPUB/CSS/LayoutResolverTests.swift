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
            minMargins: 1.0,
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 800, height: 600),
            safeAreaInsets: .zero
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
            minMargins: 1.0,
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 800, height: 600),
            safeAreaInsets: .zero
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
            minMargins: 1.0,
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 1000, height: 800),
            safeAreaInsets: .zero
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
            minMargins: 1.0, // 30
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 800, height: 600),
            safeAreaInsets: UIEdgeInsets(top: 10, left: 50, bottom: 10, right: 40)
        )

        #expect(layout.colCount == 1)
        // insets max(50, 40) = 50 > minMargins 30 -> margins = 50
        // available = 800 - 50 * 2 = 700
        #expect(layout.lineLength == 700.0)
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
            minMargins: 1.0,
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 390, height: 844),
            safeAreaInsets: .zero
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
            minMargins: 1.0,
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 1400, height: 900),
            safeAreaInsets: .zero
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
            minMargins: 1.0,
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 1400, height: 900),
            safeAreaInsets: .zero
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
            minMargins: 1.0, // 30
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 1200, height: 800),
            safeAreaInsets: .zero
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
            minMargins: 1.0, // 30
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 600, height: 800),
            safeAreaInsets: .zero
        )

        // For 2 columns: available = 600 - 120 = 480 / 2 = 240 < 440
        // Reduces to 1 column: available = 600 - 60 = 540
        #expect(layout.colCount == 1)
        #expect(layout.lineLength == 540.0)
    }

    // MARK: - EPUBSettings Overload

    @Test func layoutWithEPUBSettings() {
        let layout = resolver.layout(
            settings: settings(),
            systemFontScale: 1.0,
            viewportSize: CGSize(width: 1400, height: 900)
        )

        #expect(layout.colCount == 2)
        #expect(layout.lineLength == 640.0)
    }

    @Test func layoutWithEPUBSettingsUsesOptimalLineLengthAndPageMargins() {
        let layout = resolver.layout(
            settings: settings(optimalLineLength: 0.5, pageMargins: 2.0),
            systemFontScale: 1.0,
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
            systemFontScale: 1.0,
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
            viewportSize: CGSize(width: device.width, height: 800),
            safeAreaInsets: UIEdgeInsets(top: 0, left: device.safeArea, bottom: 0, right: device.safeArea)
        )

        #expect(layout == LayoutResolver.Layout(colCount: device.colCount, lineLength: device.lineLength))
    }

    @Test("the default maximal line length limits the height of the vertical lines")
    func defaultLayoutWithVerticalText() {
        let layout = LayoutResolver().layout(
            settings: defaultSettings(preferences: EPUBPreferences(verticalText: true)),
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
            columnCount: columnCount,
            fit: .auto,
            fontFamily: nil,
            fontSize: 1.0,
            fontWeight: nil,
            fontWidth: nil,
            hyphens: nil,
            blendImages: false,
            darkenImages: nil,
            invertImages: nil,
            invertGaiji: nil,
            language: nil,
            letterSpacing: nil,
            ligatures: nil,
            lineHeight: nil,
            linkColor: nil,
            maximalLineLength: maximalLineLength,
            minimalLineLength: minimalLineLength,
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

    @Test func systemFontScaleScalesLineLengthAndMargins() {
        let fontScale = 1.5
        let layout = resolver.layout(
            scroll: true,
            verticalText: false,
            columnCount: nil,
            optimalLineLength: 1.0,
            minimalLineLength: nil,
            maximalLineLength: nil,
            minMargins: 1.0,
            systemFontScale: fontScale,
            viewportSize: CGSize(width: 1000, height: 800),
            safeAreaInsets: .zero
        )

        // margins: 30 * 1.0 * 1.5 = 45
        // available: 1000 - 45 * 2 = 910
        #expect(layout.colCount == 1)
        #expect(layout.lineLength == 910.0)
    }
}
