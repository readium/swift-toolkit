//
//  Font.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 9/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

extension UserSettings {
    /// Font available in userSettings.
    public enum Font: Int {
        case publisher
        case sans
        case oldStyle
        case modern
        case humanist

        public static let allValues = [publisher, sans, oldStyle, modern, humanist]

        public init(with name: String) {
            switch name {
            case Font.sans.name():
                self = .sans
            case Font.oldStyle.name():
                self = .oldStyle
            case Font.modern.name():
                self = .modern
            case Font.humanist.name():
                self = .humanist
            default:
                self = .publisher
            }
        }

        /// Return the associated font name, or the CSS version.
        ///
        /// - Parameter css: If true, return the precise CSS full name.
        /// - Returns: The font name.
        public func name(css: Bool = false) -> String {
            switch self {
            case .publisher:
                return "Publisher's default"
            case .sans:
                return "Helvetica Neue"
            case .oldStyle:
                return (css ? "Iowan Old Style" : "Iowan")
            case .modern:
                return "Athelas"
            case .humanist:
                return "Seravek"
            }
        }
    }
}
