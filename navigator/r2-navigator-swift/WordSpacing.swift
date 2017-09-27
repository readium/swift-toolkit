//
//  WordSpacing.swift
//  r2-navigator-swift
//
//  Created by Alexandre Camilleri on 9/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

extension UserSettings {
    public class WordSpacing {
        public let step = 0.125
        public let min = 0.0 // Auto
        public let max = 0.5
        public var value: Double!

        public init(initialValue: Double) {
            guard initialValue > min && initialValue < max,
                (initialValue.truncatingRemainder(dividingBy: step) == 0) else
            {
                value = 0 // Auto
                return
            }
            value = initialValue
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

        public func stringValueCss() -> String {
            let stringValue = self.stringValue()

            return (value != 0 ? "\(stringValue)rem" : "0rem")
        }

        public func stringValue() -> String {
            if value == 0 {
                return "auto"
            }
            return "\(value!)"
        }
    }
}
