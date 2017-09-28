//
//  PageMargins.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 9/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

let pageMarginsDefault = 1.0

extension UserSettings {
    public class PageMargins {
        public let step = 0.25
        public let min = 0.5
        public let max = 2.0
        public var value: Double!

        public init(initialValue: Double) {
            if (initialValue < min || initialValue > max) ||
                (initialValue.truncatingRemainder(dividingBy: step) != 0)
            {
                value = 1.0
            } else {
                value = initialValue
            }
        }

        public func increment() {
            guard value + step <= max else {
                return
            }
            value = value + step
        }

        public func decrement() {
            guard value - step >= min else {
                return
            }
            value = value - step
        }

        public func stringValue() -> String {
            return "\(value!)"
        }
    }
}
