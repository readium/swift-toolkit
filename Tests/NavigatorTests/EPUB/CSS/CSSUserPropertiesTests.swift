//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
                "--USER__appearance": nil,
                "--USER__blendImages": nil,
                "--USER__darkenImages": nil,
                "--USER__invertImages": nil,
                "--USER__invertGaiji": nil,
                "--USER__textColor": nil,
                "--USER__backgroundColor": nil,
                "--USER__fontFamily": nil,
                "--USER__fontSize": nil,
                "--USER__textAlign": nil,
                "--USER__lineHeight": nil,
                "--USER__lineLength": nil,
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
                colCount: 2,
                appearance: .night,
                blendImages: true,
                darkenImages: CSSPercent(0.5),
                invertImages: CSSPercent(0.5),
                invertGaiji: CSSPercent(0.5),
                textColor: CSSHexColor("#FF0000"),
                backgroundColor: CSSHexColor("#00FF00"),
                fontFamily: ["Times New"],
                fontSize: CSSPxLength(12),
                textAlign: .justify,
                lineLength: CSSPxLength(500),
                lineHeight: .unitless(1.2),
                paraSpacing: CSSPxLength(5.6),
                paraIndent: CSSRemLength(6.7),
                wordSpacing: CSSRemLength(7.8),
                letterSpacing: CSSRemLength(8.9),
                bodyHyphens: .auto,
                ligatures: .common,
                a11yNormalize: true
            ).cssProperties(),
            [
                "--USER__view": "readium-scroll-on",
                "--USER__colCount": "2",
                "--USER__appearance": "readium-night-on",
                "--USER__blendImages": "readium-blend-on",
                "--USER__darkenImages": "50.00000%",
                "--USER__invertImages": "50.00000%",
                "--USER__invertGaiji": "50.00000%",
                "--USER__textColor": "#FF0000",
                "--USER__backgroundColor": "#00FF00",
                "--USER__fontFamily": "\"Times New\"",
                "--USER__fontSize": "12.00000px",
                "--USER__textAlign": "justify",
                "--USER__lineLength": "500.00000px",
                "--USER__lineHeight": "1.20000",
                "--USER__paraSpacing": "5.60000px",
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
            colCount: 1,
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
                colCount: 2
            ).css(),
            """
            --USER__colCount: 2 !important;
            --USER__view: readium-scroll-on !important;

            """
        )
    }

    func testGenerateFullInlineCSSProperties() {
        XCTAssertEqual(
            CSSUserProperties(
                view: .scroll,
                colCount: 2,
                appearance: .night,
                blendImages: true,
                darkenImages: CSSPercent(0.5),
                invertImages: CSSPercent(0.5),
                invertGaiji: CSSPercent(0.5),
                textColor: CSSHexColor("#FF0000"),
                backgroundColor: CSSHexColor("#00FF00"),
                fontFamily: ["Times New", "Comic Sans"],
                fontSize: CSSPxLength(12),
                textAlign: .justify,
                lineLength: CSSPxLength(500),
                lineHeight: .unitless(1.2),
                paraSpacing: CSSPxLength(5.6),
                paraIndent: CSSRemLength(6.7),
                wordSpacing: CSSRemLength(7.8),
                letterSpacing: CSSRemLength(8.9),
                bodyHyphens: .auto,
                ligatures: .common,
                a11yNormalize: true
            ).css(),
            """
            --USER__a11yNormalize: readium-a11y-on !important;
            --USER__appearance: readium-night-on !important;
            --USER__backgroundColor: #00FF00 !important;
            --USER__blendImages: readium-blend-on !important;
            --USER__bodyHyphens: auto !important;
            --USER__colCount: 2 !important;
            --USER__darkenImages: 50.00000% !important;
            --USER__fontFamily: "Times New", "Comic Sans" !important;
            --USER__fontSize: 12.00000px !important;
            --USER__invertGaiji: 50.00000% !important;
            --USER__invertImages: 50.00000% !important;
            --USER__letterSpacing: 8.90000rem !important;
            --USER__ligatures: common-ligatures !important;
            --USER__lineHeight: 1.20000 !important;
            --USER__lineLength: 500.00000px !important;
            --USER__paraIndent: 6.70000rem !important;
            --USER__paraSpacing: 5.60000px !important;
            --USER__textAlign: justify !important;
            --USER__textColor: #FF0000 !important;
            --USER__view: readium-scroll-on !important;
            --USER__wordSpacing: 7.80000rem !important;

            """
        )
    }
}
