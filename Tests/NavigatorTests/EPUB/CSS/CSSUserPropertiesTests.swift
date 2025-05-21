//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import XCTest

class CSSUserPropertiesTests: XCTestCase {
    func testConvertEmptyUserPropertiesToCSSProperties() {
        XCTAssertEqual(
            CSSUserProperties().cssProperties(),
            [
                "--USER__view": nil,
                "--USER__colCount": nil,
                "--USER__pageMargins": nil,
                "--USER__appearance": nil,
                "--USER__darkenImages": nil,
                "--USER__invertImages": nil,
                "--USER__textColor": nil,
                "--USER__backgroundColor": nil,
                "--USER__fontOverride": nil,
                "--USER__fontFamily": nil,
                "--USER__fontSize": nil,
                "--USER__advancedSettings": nil,
                "--USER__typeScale": nil,
                "--USER__textAlign": nil,
                "--USER__lineHeight": nil,
                "--USER__paraSpacing": nil,
                "--USER__paraIndent": nil,
                "--USER__wordSpacing": nil,
                "--USER__letterSpacing": nil,
                "--USER__bodyHyphens": nil,
                "--USER__ligatures": nil,
                "--USER__a11yNormalize": nil,
            ]
        )
    }

    func testConvertFullUserPropertiesToCSSProperties() {
        XCTAssertEqual(
            CSSUserProperties(
                view: .scroll,
                colCount: .auto,
                pageMargins: 1.2,
                appearance: .night,
                darkenImages: true,
                invertImages: true,
                textColor: CSSHexColor("#FF0000"),
                backgroundColor: CSSHexColor("#00FF00"),
                fontOverride: true,
                fontFamily: ["Times New"],
                fontSize: CSSVMaxLength(2.3),
                advancedSettings: true,
                typeScale: 3.4,
                textAlign: .justify,
                lineHeight: .length(CSSPtLength(4.5)),
                paraSpacing: CSSPtLength(5.6),
                paraIndent: CSSRemLength(6.7),
                wordSpacing: CSSRemLength(7.8),
                letterSpacing: CSSRemLength(8.9),
                bodyHyphens: .auto,
                ligatures: .common,
                a11yNormalize: true
            ).cssProperties(),
            [
                "--USER__view": "readium-scroll-on",
                "--USER__colCount": "auto",
                "--USER__pageMargins": "1.20000",
                "--USER__appearance": "readium-night-on",
                "--USER__darkenImages": "readium-darken-on",
                "--USER__invertImages": "readium-invert-on",
                "--USER__textColor": "#FF0000",
                "--USER__backgroundColor": "#00FF00",
                "--USER__fontOverride": "readium-font-on",
                "--USER__fontFamily": "\"Times New\"",
                "--USER__fontSize": "2.30000vmax",
                "--USER__advancedSettings": "readium-advanced-on",
                "--USER__typeScale": "3.40000",
                "--USER__textAlign": "justify",
                "--USER__lineHeight": "4.50000pt",
                "--USER__paraSpacing": "5.60000pt",
                "--USER__paraIndent": "6.70000rem",
                "--USER__wordSpacing": "7.80000rem",
                "--USER__letterSpacing": "8.90000rem",
                "--USER__bodyHyphens": "auto",
                "--USER__ligatures": "common-ligatures",
                "--USER__a11yNormalize": "readium-a11y-on",
            ]
        )
    }

    func testOverrideUserProperties() {
        let props = CSSUserProperties(
            colCount: .one,
            overrides: [
                "--USER__colCount": "2",
                "--USER__custom": "value",
            ]
        ).cssProperties()

        XCTAssertEqual(props["--USER__colCount"], "2")
        XCTAssertEqual(props["--USER__custom"], "value")
    }

    func testGenerateEmptyInlineCSSProperties() {
        XCTAssertEqual(CSSUserProperties().css(), nil)
    }

    func testGenerateMinimalInlineCSSProperties() {
        XCTAssertEqual(
            CSSUserProperties(
                view: .scroll,
                colCount: .auto
            ).css(),
            """
            --USER__colCount: auto !important;
            --USER__view: readium-scroll-on !important;

            """
        )
    }

    func testGenerateFullInlineCSSProperties() {
        XCTAssertEqual(
            CSSUserProperties(
                view: .scroll,
                colCount: .auto,
                pageMargins: 1.2,
                appearance: .night,
                darkenImages: true,
                invertImages: true,
                textColor: CSSHexColor("#FF0000"),
                backgroundColor: CSSHexColor("#00FF00"),
                fontOverride: true,
                fontFamily: ["Times New", "Comic Sans"],
                fontSize: CSSVMaxLength(2.3),
                advancedSettings: true,
                typeScale: 3.4,
                textAlign: .justify,
                lineHeight: .length(CSSPtLength(4.5)),
                paraSpacing: CSSPtLength(5.6),
                paraIndent: CSSRemLength(6.7),
                wordSpacing: CSSRemLength(7.8),
                letterSpacing: CSSRemLength(8.9),
                bodyHyphens: .auto,
                ligatures: .common,
                a11yNormalize: true
            ).css(),
            """
            --USER__a11yNormalize: readium-a11y-on !important;
            --USER__advancedSettings: readium-advanced-on !important;
            --USER__appearance: readium-night-on !important;
            --USER__backgroundColor: #00FF00 !important;
            --USER__bodyHyphens: auto !important;
            --USER__colCount: auto !important;
            --USER__darkenImages: readium-darken-on !important;
            --USER__fontFamily: "Times New", "Comic Sans" !important;
            --USER__fontOverride: readium-font-on !important;
            --USER__fontSize: 2.30000vmax !important;
            --USER__invertImages: readium-invert-on !important;
            --USER__letterSpacing: 8.90000rem !important;
            --USER__ligatures: common-ligatures !important;
            --USER__lineHeight: 4.50000pt !important;
            --USER__pageMargins: 1.20000 !important;
            --USER__paraIndent: 6.70000rem !important;
            --USER__paraSpacing: 5.60000pt !important;
            --USER__textAlign: justify !important;
            --USER__textColor: #FF0000 !important;
            --USER__typeScale: 3.40000 !important;
            --USER__view: readium-scroll-on !important;
            --USER__wordSpacing: 7.80000rem !important;

            """
        )
    }
}
