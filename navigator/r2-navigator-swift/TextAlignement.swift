//
//  TextAlignement.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 9/28/17.
//  Copyright © 2017 Readium. All rights reserved.
//

extension UserSettings {
    public enum TextAlignement: Int {
        case justify
        case left

        init(with index: Int) {
            switch index {
            case TextAlignement.left.rawValue:
                self = .left
            default:
                self = .justify
            }
        }

        func stringValue() -> String {
            switch self {
            case .justify:
                return "0"
            case .left:
                return "1"
            }
        }

        func stringValueCss() -> String {
            switch self {
            case .justify:
                return "justify"
            case .left:
                return "start" // To be left when LTR is supported later on. ??
            }
        }
    }
}
