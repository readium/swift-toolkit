//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
import R2Shared
@testable import R2Navigator

class CSSLayoutTests: XCTestCase {

    func testComputeWithAutoReadingProgression() {
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("en")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("en")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ar")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ar")), stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("fa")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("fa")), stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("he")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("he")), stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ja")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ja")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ko")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ko")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-HK")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-HK")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-Hans")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-Hans")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-Hant")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-Hant")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-TW")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-TW")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
    }

    func testComputeWithAutoReadingProgressionAndMultipleLanguages() {
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("en")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("en")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ar")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ar")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("fa")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("fa")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("he")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("he")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ja")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ja")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ko")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ko")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-HK")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-HK")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-Hans")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-Hans")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-Hant")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-Hant")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-TW")), hasMultipleLanguages: true, readingProgression: .auto, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-TW")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
    }

    func testComputeWithLTRReadingProgression() {
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("en")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("en")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ar")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ar")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("fa")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("fa")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("he")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("he")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ja")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ja")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ko")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ko")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-HK")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-HK")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-Hans")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-Hans")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-Hant")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-Hant")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-TW")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-TW")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
    }

    func testComputeWithRTLReadingProgression() {
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: nil, stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("en")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("en")), stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ar")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ar")), stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("fa")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("fa")), stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("he")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("he")), stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ja")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ja")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ko")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("ko")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-HK")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-HK")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-Hans")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-Hans")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-Hant")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-Hant")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("zh-TW")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: nil),
            CSSLayout(language: Language(code: .bcp47("zh-TW")), stylesheets: .cjkVertical, readingProgression: .rtl)
        )
    }

    func testComputeWithVerticalTextForceEnabled() {
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .auto, verticalText: true),
            CSSLayout(language: nil, stylesheets: .cjkVertical, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .ltr, verticalText: true),
            CSSLayout(language: nil, stylesheets: .cjkVertical, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .rtl, verticalText: true),
            CSSLayout(language: nil, stylesheets: .cjkVertical, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("en")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: true),
            CSSLayout(language: Language(code: .bcp47("en")), stylesheets: .cjkVertical, readingProgression: .ltr)
        )
    }

    func testComputeWithVerticalTextForceDisabled() {
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .auto, verticalText: false),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .ltr, verticalText: false),
            CSSLayout(language: nil, stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: nil, hasMultipleLanguages: false, readingProgression: .rtl, verticalText: false),
            CSSLayout(language: nil, stylesheets: .rtl, readingProgression: .rtl)
        )

        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("en")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: false),
            CSSLayout(language: Language(code: .bcp47("en")), stylesheets: .default, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ar")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: false),
            CSSLayout(language: Language(code: .bcp47("ar")), stylesheets: .rtl, readingProgression: .rtl)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ja")), hasMultipleLanguages: false, readingProgression: .auto, verticalText: false),
            CSSLayout(language: Language(code: .bcp47("ja")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ja")), hasMultipleLanguages: false, readingProgression: .ltr, verticalText: false),
            CSSLayout(language: Language(code: .bcp47("ja")), stylesheets: .cjkHorizontal, readingProgression: .ltr)
        )
        XCTAssertEqual(
            CSSLayout(language: Language(code: .bcp47("ja")), hasMultipleLanguages: false, readingProgression: .rtl, verticalText: false),
            CSSLayout(language: Language(code: .bcp47("ja")), stylesheets: .cjkHorizontal, readingProgression: .rtl)
        )
    }

    func testComputeHTMLDiStylesheets() {
        XCTAssertEqual(CSSLayout.Stylesheets.default.htmlDir, .ltr)
        XCTAssertEqual(CSSLayout.Stylesheets.rtl.htmlDir, .rtl)
        XCTAssertEqual(CSSLayout.Stylesheets.cjkVertical.htmlDir, .unspecified)
        XCTAssertEqual(CSSLayout.Stylesheets.cjkHorizontal.htmlDir, .ltr)
    }
}