//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A handle to edit the value of a specific preference which is able to predict
/// which value the `Configurable` will effectively use.
public protocol Preference {
    associatedtype Value

    /// The current value of the preference.
    var value: Value? { get }

    /// The value that will be effectively used by the navigator if preferences
    /// are submitted as they are.
    var effectiveValue: Value { get }

    /// If this preference will be effectively used by the navigator if
    /// preferences are submitted as they are.
    var isEffective: Bool { get }

    /// Set the preference to `value`. A nil value means unsetting the
    /// preference.
    func set(_ value: Value?)
}

public extension Preference {
    /// Unset the preference.
    func clear() {
        set(nil)
    }
}

public extension Preference where Value == Bool {
    /// Toggle the preference value. A default value is taken as the initial
    /// one if the preference is currently unset.
    func toggle() {
        set(!(value ?? effectiveValue))
    }

    /// Returns a new preference with its boolean value flipped.
    func flipped() -> AnyPreference<Bool> {
        map(from: { !$0 }, to: { !$0 })
            .eraseToAnyPreference()
    }
}

/// A `Preference` which accepts a closed set of values.
public protocol EnumPreference: Preference where Value: Hashable {
    /// List of valid values for this preference.
    var supportedValues: [Value] { get }
}

/// A `Preference` whose values must be in a `ClosedRange` of `Value`.
public protocol RangePreference: Preference where Value: Comparable {
    /// Supported range for the values.
    var supportedRange: ClosedRange<Value> { get }

    /// Increment the preference value from its current value or a default
    /// value.
    func increment()

    /// Decrement the preference value from its current value or a default
    /// value.
    func decrement()

    /// Format `value` in a way suitable for display, including unit if relevant.
    func format(value: Value) -> String
}

// MARK: - Type erasers

public extension Preference {
    /// Wraps this `Preference` with a type eraser.
    func eraseToAnyPreference() -> AnyPreference<Value> {
        AnyPreference(preference: self)
    }
}

/// A type-erasing `Preference` object.
public class AnyPreference<Value>: Preference {
    public var value: Value? { _value() }
    public var effectiveValue: Value { _effectiveValue() }
    public var isEffective: Bool { _isEffective() }

    private let _value: () -> Value?
    private let _effectiveValue: () -> Value
    private let _isEffective: () -> Bool
    private let _set: (Value?) -> Void

    public init<P: Preference>(preference: P) where P.Value == Value {
        _value = { preference.value }
        _effectiveValue = { preference.effectiveValue }
        _isEffective = { preference.isEffective }
        _set = preference.set
    }

    public func set(_ value: Value?) {
        _set(value)
    }
}

public extension EnumPreference {
    /// Wraps this `Preference` with a type eraser.
    func eraseToAnyPreference() -> AnyEnumPreference<Value> {
        AnyEnumPreference(enumPreference: self)
    }
}

/// A type-erasing `EnumPreference` object.
public class AnyEnumPreference<Value: Hashable>: AnyPreference<Value>, EnumPreference {
    public var supportedValues: [Value] { _supportedValues() }

    private let _supportedValues: () -> [Value]

    public init<P: EnumPreference>(enumPreference: P) where P.Value == Value {
        _supportedValues = { enumPreference.supportedValues }
        super.init(preference: enumPreference)
    }
}

public extension RangePreference {
    /// Wraps this `RangePreference` with a type eraser.
    func eraseToAnyPreference() -> AnyRangePreference<Value> {
        AnyRangePreference(rangePreference: self)
    }
}

/// A type-erasing `Preference` object.
public class AnyRangePreference<Value: Comparable>: AnyPreference<Value>, RangePreference {
    public var supportedRange: ClosedRange<Value> { _supportedRange() }

    private let _supportedRange: () -> ClosedRange<Value>
    private let _increment: () -> Void
    private let _decrement: () -> Void
    private let _format: (Value) -> String

    public init<P: RangePreference>(rangePreference: P) where P.Value == Value {
        _supportedRange = { rangePreference.supportedRange }
        _increment = rangePreference.increment
        _decrement = rangePreference.decrement
        _format = rangePreference.format(value:)
        super.init(preference: rangePreference)
    }

    public func increment() {
        _increment()
    }

    public func decrement() {
        _decrement()
    }

    public func format(value: Value) -> String {
        _format(value)
    }
}
