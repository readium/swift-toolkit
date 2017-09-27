//
//  Scroll.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 9/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

extension UserSettings {
    public enum Scroll {
        case on
        case off

        public init(with name: String) {
            switch name {
            case Scroll.on.name():
                self = .on
            default:
                self = .off
            }
        }

        public func name() -> String {
            switch self {
            case .on:
                return "readium-scroll-on"
            case .off:
                return "readium-scroll-off"
            }
        }

        public func bool() -> Bool {
            switch self {
            case .on:
                return true
            default:
                return false
            }
        }
    }
}
