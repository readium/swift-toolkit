//
//  ColumnCount.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 9/27/17.
//  Copyright © 2017 Readium. All rights

extension UserSettings {
    public enum ColumnCount: Int {
        case auto
        case one
        case two
        
        init(with name: String) {
            switch name {
            case ColumnCount.one.name():
                self = .one
            case ColumnCount.two.name():
                self = .two
            default:
                self = .auto
            }
        }
        
        public func name() -> String {
            switch self {
            case .auto:
                return "auto"
            case .one:
                return "1"
            case .two:
                return "2"
            }
        }
    }

    
}
