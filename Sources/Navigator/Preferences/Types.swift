//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// Layout axis.
public enum Axis: String, Codable, Hashable {
    case horizontal
    case vertical
}

/// Synthetic spread policy.
public enum Spread: String, Codable, Hashable {
    /// The publication should be displayed in a spread if the screen is large
    /// enough.
    case auto
    /// The publication should never be displayed in a spread.
    case never
    /// The publication should always be displayed in a spread.
    case always
}

/// Direction of the reading progression across resources.
public enum ReadingProgression: String, Codable, Hashable {
    case ltr
    case rtl

    init?(_ readingProgression: ReadiumShared.ReadingProgression) {
        switch readingProgression {
        case .ltr: self = .ltr
        case .rtl: self = .rtl
        default: return nil
        }
    }

    /// Returns the starting page for the reading progression.
    var startingPage: Properties.Page {
        switch self {
        case .ltr:
            return .right
        case .rtl:
            return .left
        }
    }
}

extension ReadiumShared.ReadingProgression {
    init(_ readingProgression: ReadingProgression) {
        switch readingProgression {
        case .ltr: self = .ltr
        case .rtl: self = .rtl
        }
    }
}

/// Method for constraining a resource inside the viewport.
public enum Fit: String, Codable, Hashable {
    case cover
    case contain
    case width
    case height
}

/// Reader theme for reflowable documents.
public enum Theme: String, Codable, Hashable {
    case light
    case dark
    case sepia

    public var contentColor: Color {
        switch self {
        case .light: return Theme.dayContentColor
        case .dark: return Theme.nightContentColor
        case .sepia: return Theme.sepiaContentColor
        }
    }

    public var backgroundColor: Color {
        switch self {
        case .light: return Theme.dayBackgroundColor
        case .dark: return Theme.nightBackgroundColor
        case .sepia: return Theme.sepiaBackgroundColor
        }
    }

    // https://github.com/readium/readium-css/blob/master/css/src/modules/ReadiumCSS-day_mode.css
    private static let dayContentColor = Color(hex: "#121212")!
    private static let dayBackgroundColor = Color(hex: "#FFFFFF")!
    // https://github.com/readium/readium-css/blob/master/css/src/modules/ReadiumCSS-night_mode.css
    private static let nightContentColor = Color(hex: "#FEFEFE")!
    private static let nightBackgroundColor = Color(hex: "#000000")!
    // https://github.com/readium/readium-css/blob/master/css/src/modules/ReadiumCSS-sepia_mode.css
    private static let sepiaContentColor = Color(hex: "#121212")!
    private static let sepiaBackgroundColor = Color(hex: "#faf4e8")!
}

/// Number of columns displayed in a reflowable document.
public enum ColumnCount: String, Codable, Hashable {
    case auto
    case one = "1"
    case two = "2"
}

/// Filter used to render images in a reflowable document.
public enum ImageFilter: String, Codable, Hashable {
    case darken
    case invert
}

/// Text alignment in a reflowable document.
public enum TextAlignment: String, Codable, Hashable {
    /// Align the text in the center of the page.
    case center
    /// Stretch lines of text that end with a soft line break to fill the width
    /// of the page.
    case justify
    /// Align the text on the leading edge of the page.
    case start
    /// Align the text on the trailing edge of the page.
    case end
    /// Align the text on the left edge of the page.
    case left
    /// Align the text on the right edge of the page.
    case right
}

/// Represents a color stored as a packed int.
public struct Color: RawRepresentable, Codable, Hashable {
    /// Packed int representation.
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Creates a color from a hex representation.
    public init?(hex: String) {
        let scanner = Scanner(string: hex.removingPrefix("#"))
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else {
            return nil
        }
        self.init(rawValue: Int(hexNumber))
    }

    /// Creates a color from a UIKit color.
    ///
    /// Any alpha component is ignored.
    public init?(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        self.init(rawValue: (r << 16) | (g << 8) | b)
    }

    /// Returns a UIKit color for the receiver.
    public var uiColor: UIColor {
        let r = CGFloat((rawValue >> 16) & 0xFF) / 255
        let g = CGFloat((rawValue >> 8) & 0xFF) / 255
        let b = CGFloat(rawValue & 0xFF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

#if canImport(SwiftUI)

    import SwiftUI

    @available(iOS 13.0, *)
    public extension Color {
        /// Creates a color from a SwiftUI color.
        @available(iOS 14.0, *)
        init?(color: SwiftUI.Color) {
            self.init(uiColor: UIColor(color))
        }

        /// Returns a SwiftUI color for the receiver.
        var color: SwiftUI.Color {
            SwiftUI.Color(uiColor)
        }
    }
#endif

/// Typeface for a publication's text.
///
/// For a list of vetted font families, see
/// https://readium.org/readium-css/docs/CSS10-libre_fonts.
public struct FontFamily: RawRepresentable, ExpressibleByStringLiteral, Codable, Hashable {
    // Generic font families
    // See https://www.w3.org/TR/css-fonts-4/#generic-font-families

    public static let serif: FontFamily = "serif"
    public static let sansSerif: FontFamily = "sans-serif"
    public static let cursive: FontFamily = "cursive"
    public static let fantasy: FontFamily = "fantasy"
    public static let monospace: FontFamily = "monospace"

    // Accessibility fonts embedded with Readium
    public static let accessibleDfA: FontFamily = "AccessibleDfA"
    public static let iaWriterDuospace: FontFamily = "IA Writer Duospace"
    public static let openDyslexic: FontFamily = "OpenDyslexic"

    // Recommended font families available on iOS
    // See https://readium.org/readium-css/docs/CSS09-default_fonts

    // Old Style (serif)
    public static let iowanOldStyle: FontFamily = "Iowan Old Style"
    public static let palatino: FontFamily = "Palatino"
    // Modern (serif)
    public static let athelas: FontFamily = "Athelas"
    public static let georgia: FontFamily = "Georgia"
    // Neutral (sans)
    public static let helveticaNeue: FontFamily = "Helvetica Neue"
    // Humanist (sans)
    public static let seravek: FontFamily = "Seravek"
    public static let arial: FontFamily = "Arial"

    /// Name of the font family.
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}
