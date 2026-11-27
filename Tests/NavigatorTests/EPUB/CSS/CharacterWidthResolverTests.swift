//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreText
@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

struct CharacterWidthResolverTests {
    @Suite("The width of a 0") struct ZeroWidth {
        @Test("in Iowan Old Style at 16pt matches the 578pt of 65 characters")
        func iowanOldStyle() {
            #expect(abs(width(.iowanOldStyle) - 578 / 65) < 0.01)
        }

        @Test("follows the font size")
        func fontSize() {
            #expect(width(.iowanOldStyle, fontSize: 1.5) == width(.iowanOldStyle) * 1.5)
        }

        @Test("is narrower in a condensed font")
        func condensedFont() {
            #expect(width("Avenir Next Condensed") < width("Avenir Next"))
        }

        @Test("is wider with a bolder weight")
        func bolderWeight() {
            #expect(width(.iowanOldStyle, fontWeight: 1.75) > width(.iowanOldStyle))
        }

        /// A face of an installed family, measured directly with CoreText.
        struct MatchedFace: Sendable, CustomTestStringConvertible {
            let name: String
            let family: FontFamily
            var fontWeight: Double?
            var fontWidth: Double?
            /// PostScript name of the expected face.
            let face: String

            var testDescription: String {
                name
            }
        }

        @Test("is measured in the face of an installed family matching the weight and width", arguments: [
            // Depends on the faces of Iowan Old Style on iOS: Roman, Bold and
            // their italics, without the Titling or Black faces of macOS.
            MatchedFace(name: "the default face", family: .iowanOldStyle, face: "IowanOldStyle-Roman"),
            MatchedFace(name: "600 without a semibold face", family: .iowanOldStyle, fontWeight: 1.5, face: "IowanOldStyle-Bold"),
            MatchedFace(name: "a condensed face", family: .helveticaNeue, fontWidth: 0.8, face: "HelveticaNeue-CondensedBold"),
        ])
        func matchedFace(_ example: MatchedFace) {
            let measured = width(example.family, fontWeight: example.fontWeight, fontWidth: example.fontWidth)
            #expect(measured == zeroWidth(inFace: example.face))
        }

        @Test("follows the weight axis of a variable font")
        func weightAxis() {
            #expect(width("system-ui", fontWeight: 1.75) == zeroWidth(in: UIFont.systemFont(ofSize: 16, weight: .bold)))
        }

        @Test("follows the width axis of a variable font")
        func widthAxis() {
            #expect(width("system-ui", fontWidth: 0.75) < width("system-ui"))
            #expect(width("system-ui", fontWidth: 1.25) > width("system-ui"))
        }

        @Test("follows the optical size of a variable font")
        func opticalSize() throws {
            let systemFontAt32 = zeroWidth(in: UIFont.systemFont(ofSize: 32))
            // Otherwise the font size alone would pass the test.
            try #require(systemFontAt32 != 2 * zeroWidth(in: UIFont.systemFont(ofSize: 16)))
            #expect(width("system-ui", fontSize: 2) == systemFontAt32)
        }

        /// An invalid weight or width, ignored.
        struct InvalidValue: Sendable, CustomTestStringConvertible {
            let name: String
            var fontWeight: Double?
            var fontWidth: Double?

            var testDescription: String {
                name
            }
        }

        @Test("ignores an invalid weight or width", arguments: [
            InvalidValue(name: "NaN weight", fontWeight: .nan),
            InvalidValue(name: "NaN width", fontWidth: .nan),
        ])
        func invalidValue(_ example: InvalidValue) {
            #expect(width("system-ui", fontWeight: example.fontWeight, fontWidth: example.fontWidth) == width("system-ui"))
        }

        @Test("is not measured with an invalid font size", arguments: [0, -1, .nan, .infinity])
        func invalidFontSize(fontSize: Double) {
            let resolver = CharacterWidthResolver()
            let measured = width(.iowanOldStyle, fontSize: fontSize, resolver: resolver)
            let expected = 578 / 65 * fontSize
            #expect(measured == expected || (measured.isNaN && expected.isNaN))
            #expect(resolver.familyLookupCount == 0)
            #expect(resolver.measurementCount == 0)
        }
    }

    @Suite("The font stack") struct FontStack {
        @Test("resolves to its first installed family, with the alternates of the declarations")
        func firstInstalledFamily() {
            let resolver = CharacterWidthResolver(fontFamilyDeclarations: [
                CSSFontFamilyDeclaration(fontFamily: "Literata", alternates: ["Unknown", .palatino, .iowanOldStyle])
                    .eraseToAnyHTMLFontFamilyDeclaration(),
            ])
            #expect(width("Literata", resolver: resolver) == width(.palatino))
        }

        @Test("skips the families declared by the app, even when installed")
        func declaredFamily() {
            let resolver = CharacterWidthResolver(fontFamilyDeclarations: [
                CSSFontFamilyDeclaration(fontFamily: .georgia, alternates: [.palatino])
                    .eraseToAnyHTMLFontFamilyDeclaration(),
            ])
            #expect(width(.georgia, resolver: resolver) == width(.palatino))
        }

        /// A family of the stack, resolved like another one.
        struct Family: Sendable, CustomTestStringConvertible {
            let family: FontFamily
            let resolvedAs: FontFamily

            var testDescription: String {
                family.rawValue
            }
        }

        @Test("resolves the generic families to the default fonts of WebKit on iOS, and the names in any case", arguments: [
            Family(family: .serif, resolvedAs: "Times New Roman"),
            Family(family: .sansSerif, resolvedAs: "Helvetica"),
            Family(family: .monospace, resolvedAs: "Courier"),
            Family(family: .cursive, resolvedAs: "Snell Roundhand"),
            Family(family: .fantasy, resolvedAs: "Papyrus"),
            Family(family: "-apple-system", resolvedAs: "system-ui"),
            Family(family: "ui-sans-serif", resolvedAs: "system-ui"),
            Family(family: "SERIF", resolvedAs: .serif),
            Family(family: "avenir next condensed", resolvedAs: "Avenir Next Condensed"),
        ])
        func family(_ example: Family) {
            #expect(width(example.family) == width(example.resolvedAs))
        }

        /// A system font design.
        struct SystemDesign: Sendable, CustomTestStringConvertible {
            let family: FontFamily
            let design: UIFontDescriptor.SystemDesign

            var testDescription: String {
                family.rawValue
            }
        }

        @Test("resolves the system font designs", arguments: [
            SystemDesign(family: "system-ui", design: .default),
            SystemDesign(family: "ui-serif", design: .serif),
            SystemDesign(family: "ui-monospace", design: .monospaced),
            SystemDesign(family: "ui-rounded", design: .rounded),
        ])
        func systemDesign(_ example: SystemDesign) {
            let descriptor = UIFont.systemFont(ofSize: 16).fontDescriptor.withDesign(example.design)!
            #expect(width(example.family) == zeroWidth(in: UIFont(descriptor: descriptor, size: 16)))
        }
    }

    /// A font measured in another family.
    struct Fallback: Sendable, CustomTestStringConvertible {
        let name: String
        let family: FontFamily?
        let measuredIn: FontFamily

        var testDescription: String {
            name
        }
    }

    /// The last resort, a constant width, is not tested as Iowan Old Style is
    /// always installed on iOS.
    @Test("a font which can't be measured falls back on another family, with the requested weight", arguments: [
        Fallback(name: "the publisher's fonts in Iowan Old Style", family: nil, measuredIn: .iowanOldStyle),
        // The standard font of WebKit.
        Fallback(name: "an unknown family in Times", family: "Unknown", measuredIn: "Times New Roman"),
    ])
    func fallback(_ example: Fallback) {
        #expect(width(example.family) == width(example.measuredIn))
        #expect(width(example.family, fontWeight: 1.75) == width(example.measuredIn, fontWeight: 1.75))
    }

    @Suite("With the CJK stylesheets, a character") struct CJK {
        @Test("is 1em wide, without measuring the font", arguments: [nil, "Avenir Next Condensed", "Unknown"] as [FontFamily?])
        func oneEm(fontFamily: FontFamily?) {
            let resolver = CharacterWidthResolver()
            #expect(width(fontFamily, fontWeight: 2, fontWidth: 2, fontSize: 1.5, isCJK: true, resolver: resolver) == 24)
            #expect(resolver.familyLookupCount == 0)
            #expect(resolver.measurementCount == 0)
        }
    }

    /// A letter spacing added to the width of a character.
    struct LetterSpacing: Sendable, CustomTestStringConvertible {
        let name: String
        let letterSpacing: Double?
        var bodyZoom: Double = 1
        var isCJK = false
        let spacing: Double

        var testDescription: String {
            name
        }
    }

    @Test("the letter spacing is added to a character, scaled by the zoom on body", arguments: [
        LetterSpacing(name: "no letter spacing", letterSpacing: nil, spacing: 0),
        LetterSpacing(name: "without zoom", letterSpacing: 0.1, spacing: 0.1 * 16),
        LetterSpacing(name: "with a zoom", letterSpacing: 0.1, bodyZoom: 1.5, spacing: 0.1 * 16 * 1.5),
        LetterSpacing(name: "negative", letterSpacing: -0.1, bodyZoom: 1.5, spacing: -0.1 * 16 * 1.5),
        LetterSpacing(name: "NaN", letterSpacing: .nan, spacing: 0),
        LetterSpacing(name: "CJK", letterSpacing: 0.1, bodyZoom: 1.5, isCJK: true, spacing: 0.1 * 16 * 1.5),
    ])
    func letterSpacing(_ example: LetterSpacing) {
        let glyph = width(.iowanOldStyle, fontSize: 1.5, isCJK: example.isCJK)
        let measured = width(.iowanOldStyle, fontSize: 1.5, letterSpacing: example.letterSpacing, bodyZoom: example.bodyZoom, isCJK: example.isCJK)
        #expect(abs(measured - (glyph + example.spacing)) < 0.000001)
    }

    @Suite("The cache") struct Cache {
        @Test("keeps the widths by family, weight, width and font size")
        func widths() {
            let resolver = CharacterWidthResolver()
            func measure(_ fontFamily: FontFamily? = .iowanOldStyle, fontWeight: Double? = nil, fontWidth: Double? = nil, fontSize: Double = 1, letterSpacing: Double? = nil) {
                _ = width(fontFamily, fontWeight: fontWeight, fontWidth: fontWidth, fontSize: fontSize, letterSpacing: letterSpacing, bodyZoom: 1.5, resolver: resolver)
            }

            measure()
            measure()
            measure(letterSpacing: 0.1)
            #expect(resolver.measurementCount == 1)

            measure(nil)
            measure(fontWeight: 1.75)
            measure(fontWidth: 1.25)
            measure(fontSize: 1.5)
            #expect(resolver.measurementCount == 5)

            measure(nil)
            measure(fontWeight: 1.75)
            measure(fontWidth: 1.25)
            measure(fontSize: 1.5)
            #expect(resolver.measurementCount == 5)
        }

        @Test("keeps the families, also when they are not installed")
        func families() {
            let resolver = CharacterWidthResolver()
            _ = width("Unknown", resolver: resolver)
            _ = width("Unknown", fontSize: 1.5, resolver: resolver)
            _ = width("Unknown", fontWeight: 1.75, resolver: resolver)
            // Unknown, then Times.
            #expect(resolver.familyLookupCount == 2)
            #expect(resolver.measurementCount == 3)
        }
    }

    /// Faces matched with a requested weight and width.
    struct Matching: Sendable, CustomTestStringConvertible {
        let name: String
        let faces: [FontFaceAttributes]
        var weight: Double = 400
        var width: Double = 100
        /// Index of the expected face.
        let expected: Int

        var testDescription: String {
            name
        }
    }

    @Test("the face is matched with the CSS font matching algorithm", arguments: [
        Matching(name: "a condensed width prefers the narrower faces", faces: [face(width: 100), face(width: 87.5)], width: 95, expected: 1),
        Matching(name: "an expanded width prefers the wider faces", faces: [face(width: 100), face(width: 112.5)], width: 105, expected: 1),
        Matching(name: "the width is matched before the weight", faces: [face(400, width: 100), face(700, width: 75)], width: 75, expected: 1),
        Matching(name: "400 prefers the heavier weights up to 500", faces: [face(300), face(500)], weight: 400, expected: 1),
        Matching(name: "450 prefers the lighter weights to the ones above 500", faces: [face(350), face(520)], weight: 450, expected: 0),
        Matching(name: "300 prefers the lighter weights", faces: [face(250), face(320)], weight: 300, expected: 0),
        Matching(name: "600 prefers the heavier weights", faces: [face(550), face(700)], weight: 600, expected: 1),
        Matching(name: "the italic faces are excluded", faces: [face(400, italic: true), face(700)], expected: 1),
        Matching(name: "an italic face is used without an upright one", faces: [face(700, italic: true), face(400, italic: true)], expected: 1),
        Matching(name: "a weight axis covers its range", faces: [face(600), face(100 ... 900)], weight: 650, expected: 1),
        Matching(name: "the closest value of a weight axis is compared", faces: [face(100 ... 300), face(500)], weight: 600, expected: 1),
        Matching(name: "the first of equally close faces is chosen", faces: [face(700), face(700)], expected: 0),
    ])
    func matching(_ example: Matching) {
        let nearest = FontFaceAttributes.nearest(in: Array(example.faces.indices), weight: example.weight, width: example.width) { example.faces[$0] }
        #expect(nearest == example.expected)
    }
}

// MARK: - Helpers

/// Returns the width of a character for `fontFamily`, at a 100% font size by
/// default.
private func width(
    _ fontFamily: FontFamily?,
    fontWeight: Double? = nil,
    fontWidth: Double? = nil,
    fontSize: Double = 1,
    letterSpacing: Double? = nil,
    bodyZoom: Double = 1,
    isCJK: Bool = false,
    resolver: CharacterWidthResolver = CharacterWidthResolver()
) -> Double {
    resolver.characterWidth(
        in: CharacterWidthResolver.Font(family: fontFamily, fontWeight: fontWeight, fontWidth: fontWidth, fontSize: fontSize),
        letterSpacing: letterSpacing,
        bodyZoom: bodyZoom,
        isCJK: isCJK
    )
}

/// Returns the attributes of a static face.
private func face(_ weight: Double = 400, width: Double = 100, italic: Bool = false) -> FontFaceAttributes {
    FontFaceAttributes(weight: weight ... weight, width: width ... width, isItalic: italic)
}

/// Returns the attributes of a face with a weight axis.
private func face(_ weight: ClosedRange<Double>) -> FontFaceAttributes {
    FontFaceAttributes(weight: weight, width: 100 ... 100, isItalic: false)
}

/// Returns the width of a `0` at 16pt in the face with the given PostScript
/// name.
private func zeroWidth(inFace postScriptName: String) -> Double {
    let font = CTFontCreateWithName(postScriptName as CFString, 16, nil)
    #expect(CTFontCopyPostScriptName(font) as String == postScriptName)
    return zeroWidth(in: font)
}

/// Returns the width of a `0` in `font`.
private func zeroWidth(in font: CTFont) -> Double {
    var character = UniChar(("0" as Unicode.Scalar).value)
    var glyph = CGGlyph()
    #expect(CTFontGetGlyphsForCharacters(font, &character, &glyph, 1))
    var advance = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
    return advance.width
}

private func zeroWidth(in font: UIFont) -> Double {
    zeroWidth(in: font as CTFont)
}
