//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct CSSUserPropertiesTests {
    @Test func convertEmptyUserPropertiesToCSSProperties() {
        #expect(
            CSSUserProperties().cssProperties() == [
                "--USER__view": nil,
                "--USER__colCount": nil,
                "--USER__lineLength": nil,
                "--USER__blendImages": nil,
                "--USER__darkenImages": nil,
                "--USER__invertImages": nil,
                "--USER__invertGaiji": nil,
                "--USER__textColor": nil,
                "--USER__backgroundColor": nil,
                "--USER__linkColor": nil,
                "--USER__visitedColor": nil,
                "--USER__fontFamily": nil,
                "--USER__fontSize": nil,
                "--USER__fontWeight": nil,
                "--USER__fontWidth": nil,
                "--USER__textAlign": nil,
                "--USER__lineHeight": nil,
                "--USER__paraSpacing": nil,
                "--USER__paraIndent": nil,
                "--USER__wordSpacing": nil,
                "--USER__letterSpacing": nil,
                "--USER__bodyHyphens": nil,
                "--USER__ligatures": nil,
                "--USER__a11yNormalize": nil,
                "--USER__noRuby": nil,
                "--USER__iOSPatch": nil,
                "--USER__iPadOSPatch": nil,
            ]
        )
    }

    @Test func convertFullUserPropertiesToCSSProperties() {
        #expect(
            CSSUserProperties(
                view: .paged,
                colCount: 2,
                lineLength: CSSPxLength(578),
                blendImages: true,
                darkenImages: 0.8,
                invertImages: 1.0,
                invertGaiji: 1.0,
                textColor: CSSIntColor(0xFF0000),
                backgroundColor: CSSIntColor(0x00FF00),
                linkColor: CSSIntColor(0x0000FF),
                visitedColor: CSSIntColor(0xFF00FF),
                fontFamily: ["Times New"],
                fontSize: CSSPercentLength(1.2),
                fontWeight: 600,
                fontWidth: CSSPercentLength(1.25),
                textAlign: .justify,
                lineHeight: 1.5,
                paraSpacing: CSSRemLength(0.5),
                paraIndent: CSSRemLength(1.0),
                wordSpacing: CSSRemLength(0.2),
                letterSpacing: CSSRemLength(0.05),
                bodyHyphens: .auto,
                ligatures: .common,
                a11yNormalize: true,
                noRuby: true,
                iOSPatch: true,
                iPadOSPatch: true
            ).cssProperties() == [
                "--USER__view": "readium-paged-on",
                "--USER__colCount": "2",
                "--USER__lineLength": "578.00000px",
                "--USER__blendImages": "readium-blend-on",
                "--USER__darkenImages": "0.80000",
                "--USER__invertImages": "1.00000",
                "--USER__invertGaiji": "1.00000",
                "--USER__textColor": "#FF0000",
                "--USER__backgroundColor": "#00FF00",
                "--USER__linkColor": "#0000FF",
                "--USER__visitedColor": "#FF00FF",
                "--USER__fontFamily": "\"Times New\"",
                "--USER__fontSize": "120.00000%",
                "--USER__fontWeight": "600",
                "--USER__fontWidth": "125.00000%",
                "--USER__textAlign": "justify",
                "--USER__lineHeight": "1.50000",
                "--USER__paraSpacing": "0.50000rem",
                "--USER__paraIndent": "1.00000rem",
                "--USER__wordSpacing": "0.20000rem",
                "--USER__letterSpacing": "0.05000rem",
                "--USER__bodyHyphens": "auto",
                "--USER__ligatures": "common-ligatures",
                "--USER__a11yNormalize": "readium-a11y-on",
                "--USER__noRuby": "readium-noRuby-on",
                "--USER__iOSPatch": "readium-iOSPatch-on",
                "--USER__iPadOSPatch": "readium-iPadOSPatch-on",
            ]
        )
    }

    @Test func disabledFlagsAreNotEmitted() {
        #expect(
            CSSUserProperties(
                blendImages: false,
                a11yNormalize: false,
                noRuby: false,
                iOSPatch: false,
                iPadOSPatch: false
            ).css() == nil
        )
    }

    @Test func generateEmptyInlineCSSProperties() {
        #expect(CSSUserProperties().css() == nil)
    }

    @Test func generateMinimalInlineCSSProperties() {
        #expect(
            CSSUserProperties(
                view: .scroll,
                colCount: 1
            ).css() == """
            --USER__colCount: 1 !important;
            --USER__view: readium-scroll-on !important;

            """
        )
    }

    @Test func generateInlineCSSPropertiesWithSeveralFontFamilies() {
        #expect(
            CSSUserProperties(fontFamily: ["Times New", "Comic Sans"]).css() == """
            --USER__fontFamily: "Times New", "Comic Sans" !important;

            """
        )
    }

    @Test func intColorIgnoresTheBitsAboveRGB() {
        #expect(CSSIntColor(0x7F00_FF00).css() == "#00FF00")
    }
}
