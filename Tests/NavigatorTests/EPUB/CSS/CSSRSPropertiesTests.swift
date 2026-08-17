//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct CSSRSPropertiesTests {
    @Test func convertEmptyPropertiesToCSSProperties() {
        #expect(
            CSSRSProperties().cssProperties() == [
                "--RS__viewportWidth": nil,
                "--RS__colWidth": nil,
                "--RS__colCount": nil,
                "--RS__colGap": nil,
                "--RS__pageGutter": nil,
                "--RS__scrollPaddingTop": nil,
                "--RS__scrollPaddingBottom": nil,
                "--RS__scrollPaddingLeft": nil,
                "--RS__scrollPaddingRight": nil,
                "--RS__flowSpacing": nil,
                "--RS__paraSpacing": nil,
                "--RS__paraIndent": nil,
                "--RS__defaultLineLength": nil,
                "--RS__maxMediaWidth": nil,
                "--RS__maxMediaHeight": nil,
                "--RS__boxSizingMedia": nil,
                "--RS__boxSizingTable": nil,
                "--RS__textColor": nil,
                "--RS__backgroundColor": nil,
                "--RS__selectionTextColor": nil,
                "--RS__selectionBackgroundColor": nil,
                "--RS__linkColor": nil,
                "--RS__visitedColor": nil,
                "--RS__primaryColor": nil,
                "--RS__secondaryColor": nil,
                "--RS__typeScale": nil,
                "--RS__baseFontFamily": nil,
                "--RS__baseLineHeight": nil,
                "--RS__oldStyleTf": nil,
                "--RS__modernTf": nil,
                "--RS__sansTf": nil,
                "--RS__humanistTf": nil,
                "--RS__monospaceTf": nil,
                "--RS__serif-ja": nil,
                "--RS__sans-serif-ja": nil,
                "--RS__serif-ja-v": nil,
                "--RS__sans-serif-ja-v": nil,
                "--RS__compFontFamily": nil,
                "--RS__codeFontFamily": nil,
            ]
        )
    }

    @Test func overrideProperties() {
        let props = CSSRSProperties(
            colCount: .one,
            overrides: [
                "--RS__colCount": "2",
                "--RS__custom": "value",
            ]
        ).cssProperties()

        #expect(props["--RS__colCount"] == "2")
        #expect(props["--RS__custom"] == "value")
    }

    @Test func convertFullPropertiesToCSSProperties() {
        #expect(
            CSSRSProperties(
                viewportWidth: CSSPercentLength(1.0),
                colWidth: CSSCmLength(1.2),
                colCount: .two,
                colGap: CSSPtLength(2.3),
                pageGutter: CSSPcLength(3.4),
                scrollPaddingTop: CSSPxLength(10),
                scrollPaddingBottom: CSSPxLength(20),
                scrollPaddingLeft: CSSPxLength(15),
                scrollPaddingRight: CSSPxLength(25),
                flowSpacing: CSSMmLength(4.5),
                paraSpacing: CSSPxLength(5.6),
                paraIndent: CSSEmLength(6.7),
                defaultLineLength: CSSRemLength(7.8),
                maxMediaWidth: CSSPercentLength(0.5),
                maxMediaHeight: CSSVwLength(9.10),
                boxSizingMedia: .borderBox,
                boxSizingTable: .contentBox,
                textColor: CSSHexColor("#432FCA"),
                backgroundColor: CSSHexColor("#FF0000"),
                selectionTextColor: CSSRGBColor(red: 100, green: 150, blue: 200),
                selectionBackgroundColor: CSSRGBColor(red: 120, green: 230, blue: 30),
                linkColor: CSSHexColor("#00FF00"),
                visitedColor: CSSHexColor("#0000FF"),
                primaryColor: CSSHexColor("#FA4358"),
                secondaryColor: CSSHexColor("#CBC322"),
                typeScale: 10.11,
                baseFontFamily: ["Palatino", "Comic Sans MS"],
                baseLineHeight: .length(CSSVhLength(11.12)),
                oldStyleTf: ["Old", "Style"],
                modernTf: ["Modern", "Tf"],
                sansTf: ["Sans"],
                humanistTf: ["Humanist"],
                monospaceTf: ["Monospace"],
                serifJa: ["Serif", "Ja"],
                sansSerifJa: ["Sans serif", "Ja"],
                serifJaV: ["Serif", "JaV"],
                sansSerifJaV: ["Sans serif", "JaV"],
                compFontFamily: ["Arial"],
                codeFontFamily: ["Monaco", "Console Sans"]
            ).cssProperties() == [
                "--RS__viewportWidth": "100.00000%",
                "--RS__colWidth": "1.20000cm",
                "--RS__colCount": "2",
                "--RS__colGap": "2.30000pt",
                "--RS__pageGutter": "3.40000pc",
                "--RS__scrollPaddingTop": "10.00000px",
                "--RS__scrollPaddingBottom": "20.00000px",
                "--RS__scrollPaddingLeft": "15.00000px",
                "--RS__scrollPaddingRight": "25.00000px",
                "--RS__flowSpacing": "4.50000mm",
                "--RS__paraSpacing": "5.60000px",
                "--RS__paraIndent": "6.70000em",
                "--RS__defaultLineLength": "7.80000rem",
                "--RS__maxMediaWidth": "50.00000%",
                "--RS__maxMediaHeight": "9.10000vw",
                "--RS__boxSizingMedia": "border-box",
                "--RS__boxSizingTable": "content-box",
                "--RS__textColor": "#432FCA",
                "--RS__backgroundColor": "#FF0000",
                "--RS__selectionTextColor": "rgb(100, 150, 200)",
                "--RS__selectionBackgroundColor": "rgb(120, 230, 30)",
                "--RS__linkColor": "#00FF00",
                "--RS__visitedColor": "#0000FF",
                "--RS__primaryColor": "#FA4358",
                "--RS__secondaryColor": "#CBC322",
                "--RS__typeScale": "10.11000",
                "--RS__baseFontFamily": #"Palatino, "Comic Sans MS""#,
                "--RS__baseLineHeight": "11.12000vh",
                "--RS__oldStyleTf": #"Old, Style"#,
                "--RS__modernTf": #"Modern, Tf"#,
                "--RS__sansTf": #"Sans"#,
                "--RS__humanistTf": #"Humanist"#,
                "--RS__monospaceTf": #"Monospace"#,
                "--RS__serif-ja": #"Serif, Ja"#,
                "--RS__sans-serif-ja": #""Sans serif", Ja"#,
                "--RS__serif-ja-v": #"Serif, JaV"#,
                "--RS__sans-serif-ja-v": #""Sans serif", JaV"#,
                "--RS__compFontFamily": #"Arial"#,
                "--RS__codeFontFamily": #"Monaco, "Console Sans""#,
            ]
        )
    }

    @Test func deprecatedMaxLineLength() {
        var props = CSSRSProperties(maxLineLength: CSSRemLength(5.0))
        #expect(props.defaultLineLength?.value == 5.0)
        #expect(props.maxLineLength?.value == 5.0)

        props.maxLineLength = CSSRemLength(6.0)
        #expect(props.defaultLineLength?.value == 6.0)
        #expect(props.cssProperties()["--RS__defaultLineLength"] == "6.00000rem")
    }
}
