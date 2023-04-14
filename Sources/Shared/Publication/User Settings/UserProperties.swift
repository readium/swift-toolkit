//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public protocol UserPropertyStringifier {
    func toString() -> String
}

public class UserProperty: UserPropertyStringifier {
    public var reference: String
    public var name: String

    init(_ reference: String, _ name: String) {
        self.reference = reference
        self.name = name
    }

    public func toString() -> String {
        ""
    }
}

public class Enumerable: UserProperty {
    public var index: Int
    public var values: [String]

    init(index: Int, values: [String], reference: String, name: String) {
        self.index = index
        self.values = values

        super.init(reference, name)
    }

    override public func toString() -> String {
        values[index]
    }
}

public class Incrementable: UserProperty {
    public var value, min, max, step: Float
    public var suffix: String

    init(value: Float, min: Float, max: Float, step: Float, suffix: String, reference: String, name: String) {
        self.value = value
        self.min = min
        self.max = max
        self.step = step
        self.suffix = suffix

        super.init(reference, name)
    }

    public func increment() {
        value += ((value + step) <= max) ? step : 0.0
    }

    public func decrement() {
        value -= ((value - step) >= min) ? step : 0.0
    }

    override public func toString() -> String {
        "\(value)" + suffix
    }
}

public class Switchable: UserProperty {
    public var onValue: String
    public var offValue: String
    public var on: Bool
    public var values: [Bool: String]

    init(onValue: String, offValue: String, on: Bool, reference: String, name: String) {
        self.onValue = onValue
        self.offValue = offValue
        self.on = on

        values = [true: onValue, false: offValue]

        super.init(reference, name)
    }

    public func switchValue() {
        on = !on
    }

    override public func toString() -> String {
        values[on]!
    }
}

public class StringProperty: UserProperty {
    public var value: String?

    init(value: String?, reference: String, name: String) {
        self.value = value

        super.init(reference, name)
    }

    override public func toString() -> String {
        value ?? ""
    }
}

public class UserProperties {
    public var properties = [UserProperty]()

    public init() {}

    public func addEnumerable(index: Int, values: [String], reference: String, name: String) {
        properties.append(Enumerable(index: index, values: values, reference: reference, name: name))
    }

    public func addIncrementable(nValue: Float, min: Float, max: Float, step: Float, suffix: String, reference: String, name: String) {
        properties.append(Incrementable(value: nValue, min: min, max: max, step: step, suffix: suffix, reference: reference, name: name))
    }

    public func addSwitchable(onValue: String, offValue: String, on: Bool, reference: String, name: String) {
        properties.append(Switchable(onValue: onValue, offValue: offValue, on: on, reference: reference, name: name))
    }

    public func addString(value: String?, reference: String, name: String) {
        properties.append(StringProperty(value: value, reference: reference, name: name))
    }

    public func getProperty(reference: String) -> UserProperty? {
        properties.filter { $0.reference == reference }.first
    }

    /// Removes a property matching a ReadiumCSS reference.
    /// - Parameter ref: The CSS reference of the property to be removed.
    public func removeProperty(forReference ref: ReadiumCSSReference) {
        properties.removeAll {
            $0.reference == ref.rawValue
        }
    }
}
