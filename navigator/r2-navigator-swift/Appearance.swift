//
//  Appearance.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 9/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit

extension UserSettings {
    /// Appearances available in UserSettings.
    public enum Appearance: Int {
        case `default`
        case sepia
        case night

        public init(with name: String) {
            switch name {
            case Appearance.sepia.name():
                self = .sepia
            case Appearance.night.name():
                self = .night
            default:
                self = .default
            }
        }

        /// The associated name for ReadiumCss.
        ///
        /// - Returns: Appearance name.
        public func name() -> String{
            switch self {
            case .default:
                return "readium-default-on"
            case .sepia:
                return "readium-sepia-on"
            case .night:
                return "readium-night-on"
            }
        }

        /// The associated color for the UI.
        ///
        /// - Returns: Color.
        public func associatedColor() -> UIColor {
            switch self {
            case .default:
                return UIColor.white
            case .sepia:
                return UIColor.init(red: 250/255, green: 244/255, blue: 232/255, alpha: 1)
            case .night:
                return UIColor.black

            }
        }

        /// The associated color for the fonts.
        ///
        /// - Returns: Color.
        public func associatedFontColor() -> UIColor {
            switch self {
            case .default:
                return UIColor.black
            case .sepia:
                return UIColor.init(red: 18/255, green: 18/255, blue: 18/255, alpha: 1)
            case .night:
                return UIColor.init(red: 254/255, green: 254/255, blue: 254/255, alpha: 1)

            }
        }
    }
}
