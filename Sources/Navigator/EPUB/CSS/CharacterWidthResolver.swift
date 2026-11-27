//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreText
import Foundation
import ReadiumShared
import UIKit

/// Measures the width of the characters counted by the EPUB line lengths, as
/// rendered in the web views.
///
/// A character is a `0` (the CSS `ch` unit), measured with CoreText in the
/// first family of the `font-family` stack installed on the device, or a
/// full-width ideograph of 1em (the CSS `ic` unit) with the CJK stylesheets.
///
/// The fallbacks follow the font WebKit renders in each case:
///
/// - With a `fontFamily` setting whose stack has no installed family, Times.
///   Readium CSS sets `font-family: var(--USER__fontFamily) !important`
///   without a generic family at the end, so WebKit uses its standard font,
///   Times on iOS.
/// - Without a `fontFamily` setting, Iowan Old Style. Readium CSS doesn't
///   override the font, so the text is in the publisher's fonts, which can't
///   be measured, or in the Readium CSS default `--RS__baseFontFamily`,
///   which starts with Iowan Old Style for Latin text. Other languages get
///   other defaults (e.g. Thonburi in Thai), measured in Iowan Old Style
///   anyway.
///
/// Iowan Old Style is also the last font tried after Times, then a constant
/// width, but they are not reached with the fonts installed on iOS.
///
/// The families declared by the app in `fontFamilyDeclarations` are not
/// measured: they are skipped, so the stack continues with their alternates.
final class CharacterWidthResolver: Sendable {
    /// Font size of the text at a 100% `fontSize` setting, in points. A CSS
    /// px is a point in the web views.
    static let baseFontSize: Double = 16

    /// Width of a `0` in Iowan Old Style, in ems: 65 of them measure 578pt
    /// at the 16pt base font size. Used only when no font can be measured,
    /// which doesn't happen with the fonts installed on iOS.
    private static let iowanCharacterWidth: Double = 578 / 65 / baseFontSize

    /// Font of the text, from the settings.
    struct Font: Hashable, Sendable {
        /// Font family, or `nil` for the publisher's fonts.
        let family: FontFamily?

        /// CSS `font-weight`.
        let weight: Double

        /// CSS `font-stretch`, in percent.
        let width: Double

        /// Font size, in points.
        let size: Double

        /// - Parameters:
        ///   - family: `fontFamily` setting, `nil` for the publisher's fonts.
        ///   - fontWeight: `fontWeight` setting, a factor of the normal
        ///     weight.
        ///   - fontWidth: `fontWidth` setting, a factor of the normal width.
        ///   - fontSize: `fontSize` setting, a factor of the base font size.
        init(family: FontFamily?, fontWeight: Double?, fontWidth: Double?, fontSize: Double) {
            self.family = family
            // Same values as the `--USER__fontWeight` and `--USER__fontWidth`
            // properties set by `ReadiumCSS.update`.
            weight = Double(ReadiumCSS.fontWeight(fontWeight) ?? CSSStandardFontWeight.normal.rawValue)
            width = fontWidth.takeIf { !$0.isNaN }.map { $0 * 100 } ?? 100
            size = CharacterWidthResolver.baseFontSize * fontSize
        }
    }

    private let fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration]
    private let state = Mutex(State())

    private struct State {
        /// Widths of a `0`, in points.
        var zeroWidths: [Font: Double] = [:]
        /// Faces of the font families. A family which is not installed has
        /// no faces.
        var families: [FamilySource: [Face]] = [:]
        var measurementCount = 0
        var familyLookupCount = 0
    }

    /// Test hook: number of fonts measured with CoreText, without the cached
    /// widths.
    var measurementCount: Int {
        state.withLock { $0.measurementCount }
    }

    /// Test hook: number of font families looked up with CoreText, without
    /// the cached families.
    var familyLookupCount: Int {
        state.withLock { $0.familyLookupCount }
    }

    init(fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration] = []) {
        self.fontFamilyDeclarations = fontFamilyDeclarations
    }

    /// Returns the width of one character of the line lengths in `font`, in
    /// points, as rendered with the letter spacing.
    ///
    /// - Parameters:
    ///   - letterSpacing: Letter spacing in rem, or `nil` when it doesn't
    ///     apply.
    ///   - bodyZoom: `zoom` applied by Readium CSS on `body`, see
    ///     `ReadiumCSS.bodyZoom(fontSize:userInterfaceIdiom:)`.
    ///   - isCJK: Whether the text is laid out with the CJK stylesheets.
    func characterWidth(in font: Font, letterSpacing: Double?, bodyZoom: Double, isCJK: Bool) -> Double {
        let glyphWidth = isCJK
            // A full-width ideograph is 1em wide (the CSS `ic` unit).
            ? font.size
            // The width of a `0` (the CSS `ch` unit).
            : zeroWidth(in: font)

        // The letter spacing is a rem length, so it follows the `zoom` on
        // `body` but not the `-webkit-text-size-adjust` of the iOS patch. It
        // isn't clamped by the preferences, so it can be NaN.
        guard let letterSpacing, !letterSpacing.isNaN else {
            return glyphWidth
        }
        return glyphWidth + letterSpacing * Self.baseFontSize * bodyZoom
    }

    /// Returns the width of a `0` in `font`, from the cache when possible.
    ///
    /// The lock is not held while CoreText looks up and measures the fonts,
    /// so a width can occasionally be measured twice.
    private func zeroWidth(in font: Font) -> Double {
        guard font.size.isFinite, font.size > 0 else {
            return Self.iowanCharacterWidth * font.size
        }
        if let cached = state.withLock({ $0.zeroWidths[font] }) {
            return cached
        }

        let width = measureZeroWidth(in: font)
        state.withLock { $0.zeroWidths[font] = width }
        return width
    }

    /// Measures a `0` in the first family of the font stack of `font` which
    /// can be measured.
    private func measureZeroWidth(in font: Font) -> Double {
        var sources: [FamilySource] = []
        if let family = font.family {
            sources = ReadiumCSS.resolveFontStack(of: family, declarations: fontFamilyDeclarations)
                .compactMap(source(of:))
            // The standard font of WebKit, used when no family of the stack
            // is installed.
            sources.append(.installed("times"))
        }
        // The Readium CSS default font for Latin text, standing in for the
        // publisher's fonts. Also the last resort after Times.
        sources.append(.installed(FontFamily.iowanOldStyle.rawValue.lowercased()))

        for source in sources {
            if let width = measureZeroWidth(in: source, font: font) {
                return width
            }
        }
        return Self.iowanCharacterWidth * font.size
    }

    /// Measures a `0` in the face of the family `source` the closest to
    /// `font`, or returns `nil` if the family is not installed.
    private func measureZeroWidth(in source: FamilySource, font: Font) -> Double? {
        guard let face = FontFaceAttributes.nearest(in: faces(of: source), weight: font.weight, width: font.width, attributes: \.attributes) else {
            return nil
        }
        state.withLock { $0.measurementCount += 1 }
        return face.zeroWidth(weight: font.weight, width: font.width, size: font.size)
    }

    // MARK: - Font families

    /// Source of the faces of a font family.
    private enum FamilySource: Hashable {
        /// A family installed on the device, by lowercased name.
        case installed(String)
        /// The system font with the given design.
        case system(SystemDesign)
    }

    private enum SystemDesign: Hashable {
        case `default`, serif, monospaced, rounded

        var uiDesign: UIFontDescriptor.SystemDesign {
            switch self {
            case .default: return .default
            case .serif: return .serif
            case .monospaced: return .monospaced
            case .rounded: return .rounded
            }
        }
    }

    /// Returns the source of a family of the CSS `font-family` stack, or
    /// `nil` for a family declared by the app, which is not measured.
    private func source(of family: String) -> FamilySource? {
        guard !fontFamilyDeclarations.contains(where: { $0.fontFamily.rawValue == family }) else {
            return nil
        }

        // The CSS keywords are case-insensitive. The generic families are the
        // default fonts of WebKit on iOS.
        let family = family.lowercased()
        switch family {
        case "serif":
            return .installed("times")
        case "sans-serif":
            return .installed("helvetica")
        case "monospace":
            return .installed("courier")
        case "cursive":
            return .installed("snell roundhand")
        case "fantasy":
            return .installed("papyrus")
        case "system-ui", "-apple-system", "ui-sans-serif":
            return .system(.default)
        case "ui-serif":
            return .system(.serif)
        case "ui-monospace":
            return .system(.monospaced)
        case "ui-rounded":
            return .system(.rounded)
        default:
            return .installed(family)
        }
    }

    /// Returns the faces of the family `source`, from the cache when
    /// possible.
    private func faces(of source: FamilySource) -> [Face] {
        if let cached = state.withLock({ $0.families[source] }) {
            return cached
        }

        let faces: [Face] = switch source {
        case let .installed(name):
            Self.faces(ofInstalledFamily: name)
        case let .system(design):
            Self.faces(ofSystemDesign: design)
        }

        state.withLock {
            $0.families[source] = faces
            $0.familyLookupCount += 1
        }
        return faces
    }

    /// Returns the faces of a font family installed on the device, its
    /// default face first.
    ///
    /// Unlike `CTFontCreateWithName`, which silently substitutes a missing
    /// family, matching the family name returns no faces when the family is
    /// not installed. It also finds a family by its localized name, or by an
    /// alias such as Times for Times New Roman, like WebKit.
    private static func faces(ofInstalledFamily name: String) -> [Face] {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: name] as CFDictionary)
        let mandatoryAttributes = Set([kCTFontFamilyNameAttribute as String]) as CFSet
        guard
            let matches = CTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatoryAttributes) as? [CTFontDescriptor],
            !matches.isEmpty
        else {
            return []
        }

        // The faces equally close to the requested font go to the first one,
        // so they are sorted instead of relying on the order of CoreText.
        let defaultFace = CTFontDescriptorCreateMatchingFontDescriptor(descriptor, mandatoryAttributes)
            .flatMap(postScriptName(of:))
        let sorted = matches
            .map { (name: postScriptName(of: $0) ?? "", descriptor: $0) }
            .sorted { lhs, rhs in
                if (lhs.name == defaultFace) != (rhs.name == defaultFace) {
                    return lhs.name == defaultFace
                }
                return lhs.name < rhs.name
            }
        return sorted.map { Face(descriptor: $0.descriptor) }
    }

    private static func postScriptName(of descriptor: CTFontDescriptor) -> String? {
        CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
    }

    /// Returns the variable face of the system font with the given design.
    private static func faces(ofSystemDesign design: SystemDesign) -> [Face] {
        guard let descriptor = UIFont.systemFont(ofSize: baseFontSize).fontDescriptor.withDesign(design.uiDesign) else {
            return []
        }
        return [Face(descriptor: descriptor as CTFontDescriptor)]
    }
}

/// A face of a font family installed on the device.
///
/// CoreText font descriptors are immutable and can be used from any thread.
private struct Face: @unchecked Sendable {
    let descriptor: CTFontDescriptor
    let attributes: FontFaceAttributes

    /// Variation axes of the face, when its descriptor has them (the system
    /// fonts). Otherwise they are read from the measured font.
    private let axes: [Int: ClosedRange<Double>]?

    init(descriptor: CTFontDescriptor) {
        self.descriptor = descriptor
        axes = CTFontDescriptorCopyAttribute(descriptor, kCTFontVariationAxesAttribute)
            .map(FontFaceAttributes.variationAxes)
        attributes = FontFaceAttributes(descriptor: descriptor, axes: axes ?? [:])
    }

    /// Returns the width of a `0` in this face at `size`, with its `wght` and
    /// `wdth` variation axes, if any, set to the requested CSS `weight` and
    /// `width`. The optical size follows the font size.
    func zeroWidth(weight: Double, width: Double, size: Double) -> Double? {
        var font: CTFont?
        let axes: [Int: ClosedRange<Double>]
        if let descriptorAxes = self.axes {
            axes = descriptorAxes
        } else {
            // Without axes in the descriptor, they are read only for the
            // measured face, as reading them for every face of a family
            // requires to create a font for each.
            let defaultFont = CTFontCreateWithFontDescriptor(descriptor, size, nil)
            font = defaultFont
            axes = FontFaceAttributes.variationAxes(CTFontCopyVariationAxes(defaultFont))
        }

        var variations: [NSNumber: NSNumber] = [:]
        if let range = axes[FontFaceAttributes.weightAxis] {
            variations[NSNumber(value: FontFaceAttributes.weightAxis)] = NSNumber(value: weight.clamped(to: range))
        }
        if let range = axes[FontFaceAttributes.widthAxis] {
            variations[NSNumber(value: FontFaceAttributes.widthAxis)] = NSNumber(value: width.clamped(to: range))
        }
        if !variations.isEmpty {
            let variableDescriptor = CTFontDescriptorCreateCopyWithAttributes(descriptor, [kCTFontVariationAttribute: variations] as CFDictionary)
            font = CTFontCreateWithFontDescriptor(variableDescriptor, size, nil)
        }
        let measuredFont = font ?? CTFontCreateWithFontDescriptor(descriptor, size, nil)

        var character = UniChar(("0" as Unicode.Scalar).value)
        var glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(measuredFont, &character, &glyph, 1) else {
            return nil
        }
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(measuredFont, .horizontal, &glyph, &advance, 1)
        return advance.width
    }
}

/// Attributes of a font face used to match it with a requested font.
struct FontFaceAttributes: Equatable, Sendable {
    /// CSS `font-weight` values covered by the face: a range with a `wght`
    /// variation axis.
    var weight: ClosedRange<Double>

    /// CSS `font-stretch` percentages covered by the face: a range with a
    /// `wdth` variation axis.
    var width: ClosedRange<Double>

    var isItalic: Bool

    init(weight: ClosedRange<Double>, width: ClosedRange<Double>, isItalic: Bool) {
        self.weight = weight
        self.width = width
        self.isItalic = isItalic
    }

    /// Reads the attributes of an installed font face from its traits, and
    /// from its variation `axes`, by identifier.
    init(descriptor: CTFontDescriptor, axes: [Int: ClosedRange<Double>]) {
        let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [String: Any] ?? [:]
        let weightTrait = (traits[kCTFontWeightTrait as String] as? NSNumber)?.doubleValue ?? 0
        let widthTrait = (traits[kCTFontWidthTrait as String] as? NSNumber)?.doubleValue ?? 0
        let symbolicTraits = (traits[kCTFontSymbolicTrait as String] as? NSNumber)?.uint32Value ?? 0

        self.init(
            weight: axes[Self.weightAxis] ?? Self.cssWeight(ofTrait: weightTrait).singleValueRange,
            width: axes[Self.widthAxis] ?? Self.cssWidth(ofTrait: widthTrait).singleValueRange,
            isItalic: symbolicTraits & CTFontSymbolicTraits.traitItalic.rawValue != 0
        )
    }

    static let weightAxis = 0x7767_6874 // 'wght'
    static let widthAxis = 0x7764_7468 // 'wdth'

    /// Returns the ranges of the variation axes, by identifier.
    static func variationAxes(_ axes: CFTypeRef?) -> [Int: ClosedRange<Double>] {
        var ranges: [Int: ClosedRange<Double>] = [:]
        for axis in axes as? [[String: Any]] ?? [] {
            guard
                let identifier = (axis[kCTFontVariationAxisIdentifierKey as String] as? NSNumber)?.intValue,
                let minimum = (axis[kCTFontVariationAxisMinimumValueKey as String] as? NSNumber)?.doubleValue,
                let maximum = (axis[kCTFontVariationAxisMaximumValueKey as String] as? NSNumber)?.doubleValue,
                minimum <= maximum
            else {
                continue
            }
            ranges[identifier] = minimum ... maximum
        }
        return ranges
    }

    // MARK: Font matching

    /// Returns the face the closest to the requested CSS `weight` and
    /// `width`, following the CSS font matching algorithm: first the width,
    /// then the upright faces, then the weight. The faces equally close go
    /// to the first one.
    ///
    /// See https://www.w3.org/TR/css-fonts-4/#font-style-matching
    static func nearest<Face>(
        in faces: [Face],
        weight: Double,
        width: Double,
        attributes: (Face) -> FontFaceAttributes
    ) -> Face? {
        var candidates = nearest(faces, to: width, in: { attributes($0).width }) { value in
            // Narrower widths first when the requested width is condensed,
            // wider widths first otherwise.
            width <= 100 ? (value < width ? 0 : 1) : (value > width ? 0 : 1)
        }

        let upright = candidates.filter { !attributes($0).isItalic }
        if !upright.isEmpty {
            candidates = upright
        }

        candidates = nearest(candidates, to: weight, in: { attributes($0).weight }) { value in
            if (400 ... 500).contains(weight) {
                // Heavier weights up to 500 first, then lighter, then the
                // heavier weights above 500.
                if value > weight, value <= 500 {
                    return 0
                }
                return value < weight ? 1 : 2
            } else if weight < 400 {
                // Lighter weights first, then heavier.
                return value < weight ? 0 : 1
            } else {
                // Heavier weights first, then lighter.
                return value > weight ? 0 : 1
            }
        }

        return candidates.first
    }

    /// Keeps the faces whose `range` is the closest to `desired`, in order.
    ///
    /// The faces covering `desired` are the closest. The other ones are
    /// sorted by `group`, the order of preference of a value which is not
    /// `desired`, then by distance.
    private static func nearest<Face>(
        _ faces: [Face],
        to desired: Double,
        in range: (Face) -> ClosedRange<Double>,
        group: (Double) -> Int
    ) -> [Face] {
        func rank(_ face: Face) -> (Int, Double) {
            let value = desired.clamped(to: range(face))
            return value == desired ? (0, 0) : (group(value) + 1, abs(value - desired))
        }

        guard let best = faces.map(rank).min(by: <) else {
            return []
        }
        return faces.filter { rank($0) == best }
    }

    /// CSS weights of the CoreText weight traits used by the system fonts,
    /// such as `UIFont.Weight.ultraLight` (-0.8) for 100.
    private static let weightTraits: [(trait: Double, weight: Double)] = [
        (-1, 1), (-0.8, 100), (-0.6, 200), (-0.4, 300), (0, 400),
        (0.23, 500), (0.3, 600), (0.4, 700), (0.56, 800), (0.62, 900), (1, 1000),
    ]

    /// Returns the CSS `font-weight` of a CoreText weight trait, interpolated
    /// between the weights of the system fonts.
    private static func cssWeight(ofTrait trait: Double) -> Double {
        let trait = trait.clamped(to: -1 ... 1)
        guard let upper = weightTraits.firstIndex(where: { trait <= $0.trait }), upper > 0 else {
            return weightTraits[0].weight
        }
        let (t0, w0) = weightTraits[upper - 1]
        let (t1, w1) = weightTraits[upper]
        return w0 + (trait - t0) / (t1 - t0) * (w1 - w0)
    }

    /// Returns the CSS `font-stretch` percentage of a CoreText width trait,
    /// e.g. 80% for the condensed faces of Avenir Next (-0.2).
    private static func cssWidth(ofTrait trait: Double) -> Double {
        100 * (1 + trait.clamped(to: -1 ... 1))
    }
}

private extension Double {
    var singleValueRange: ClosedRange<Double> {
        self ... self
    }
}
