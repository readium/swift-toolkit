//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
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

    public init?(_ readingProgression: R2Shared.ReadingProgression) {
        switch readingProgression {
            case .ltr: self = .ltr
            case .rtl: self = .rtl
            default: return nil
        }
    }
    
    /// Returns the leading Page for the reading progression.
    var leadingPage: Presentation.Page {
        switch self {
        case .ltr:
            return .left
        case .rtl:
            return .right
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

/// Represents a color stored as a packed int.
public struct Color: RawRepresentable, Codable, Hashable {

    /// Packed int representation.
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Creates a color from a UIKit color.
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
        let a = Int(alpha * 255)
        self.init(rawValue: (a << 24) | (r << 16) | (g << 8) | b)
    }
    
    /// Returns a UIKit color for the receiver.
    public var uiColor: UIColor {
        let a = CGFloat((rawValue >> 24) & 0xFF) / 255
        let r = CGFloat((rawValue >> 16) & 0xFF) / 255
        let g = CGFloat((rawValue >> 8) & 0xFF) / 255
        let b = CGFloat(rawValue & 0xFF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: a)
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
