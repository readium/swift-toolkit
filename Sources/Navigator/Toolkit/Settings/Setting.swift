//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a single configurable property of a `Configurable` component and holds its current
/// `value`.
public class Setting<Value: Hashable> {

    /// Unique identifier used to serialize `Preferences` to JSON.
    public let key: SettingKey<Value>

    /// Current value for this setting.
    public let value: Value

    /// Ensures the validity of a `value`.
    private let validator: SettingValidator<Value>

    /// Ensures that the condition required for this setting to be active are met in the given
    /// `Preferences` – e.g. another setting having a certain preference.
    private let activator: SettingActivator

    public init(
        key: SettingKey<Value>,
        value: Value,
        validator: @escaping SettingValidator<Value> = { $0 },
        activator: SettingActivator = NullSettingActivator()
    ) {
        self.key = key
        self.value = value
        self.validator = validator
        self.activator = activator
    }

    public func validate(_ value: Value) -> Value? {
        validator(value)
    }
}

extension Setting: SettingActivator {
    public func isActive(with preferences: Preferences) -> Bool {
        activator.isActive(with: preferences)
    }

    public func activate(in preferences: inout Preferences) {
        activator.activate(in: &preferences)
    }
}

/// Unique identifier used to serialize `Preferences` to JSON.
public struct SettingKey<Value: Hashable> {
    /// Unique identifier for this setting key.
    public let id: String

    /// JSON serializer for the value of this key.
    public let coder: SettingCoder<Value>

    public init(id: String, coder: SettingCoder<Value>) {
        self.id = id
        self.coder = coder
    }
}

extension SettingKey where Value: RawRepresentable {
    public init(_ id: String) {
        self.init(id: id, coder: .rawValue())
    }
}

extension SettingKey where Value == Bool {
    public init(_ id: String) {
        self.init(id: id, coder: .literal())
    }
}

extension SettingKey where Value == Int {
    public init(_ id: String) {
        self.init(id: id, coder: .literal())
    }
}

extension SettingKey where Value == Double {
    public init(_ id: String) {
        self.init(id: id, coder: .literal())
    }
}

extension SettingKey where Value == String {
    public init(_ id: String) {
        self.init(id: id, coder: .literal())
    }
}


/// Returns a valid value for the given `value`, if possible.
///
/// For example, a range setting will coerce the value to be in the range.
public typealias SettingValidator<Value> = (Value) -> Value?

/// A boolean `Setting`.
public typealias ToggleSetting = Setting<Bool>

/// A `Setting` whose value is constrained to a range.
public class RangeSetting<Value: Comparable & Hashable>: Setting<Value> {
    /// The valid range for the setting value.
    public let range: ClosedRange<Value>

    /// Value steps which can be used to decrement or increment the setting. It MUST be sorted in
    /// increasing order.
    public let suggestedSteps: [Value]?

    /// Suggested value increment which can be used to decrement or increment the setting.
    public let suggestedIncrement: Value?

    /// Returns a user-facing description for the given value. This can be used to format the value
    /// unit.
    public let formatValue: (Value) -> String

    public init(
        key: SettingKey<Value>,
        value: Value,
        range: ClosedRange<Value>,
        suggestedSteps: [Value]? = nil,
        suggestedIncrement: Value? = nil,
        formatValue: ((Value) -> String)? = nil,
        validator: @escaping SettingValidator<Value> = { $0 },
        activator: SettingActivator = NullSettingActivator()
    ) {
        self.range = range
        self.suggestedSteps = suggestedSteps
        self.suggestedIncrement = suggestedIncrement
        self.formatValue = formatValue ?? { value in
            (value as? NSNumber)
                .flatMap { rangeValueFormatter.string(from: $0) }
                ?? String(describing: value)
        }

        super.init(
            key: key, value: value,
            validator: { value in
                validator(value).flatMap { $0.clamped(to: range) }
            },
            activator: activator
        )
    }
}

private let rangeValueFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 5
    return f
}()

/// A `RangeSetting` representing a percentage from 0.0 to 1.0.
public class PercentSetting: RangeSetting<Double> {
    public override init(
        key: SettingKey<Double>,
        value: Double,
        range: ClosedRange<Double> = 0.0...1.0,
        suggestedSteps: [Double]? = nil,
        suggestedIncrement: Double? = 0.1,
        formatValue: ((Double) -> String)? = nil,
        validator: @escaping SettingValidator<Double> = { $0 },
        activator: SettingActivator = NullSettingActivator()
    ) {
        super.init(
            key: key, value: value, range: range, suggestedSteps: suggestedSteps,
            suggestedIncrement: suggestedIncrement,
            formatValue: formatValue ?? { value in
                percentValueFormatter.string(from: value as NSNumber)
                    ?? String(format: "%.0f%%", value * 100)
            },
            validator: validator,
            activator: activator
        )
    }
}

private let percentValueFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .percent
    f.minimumIntegerDigits = 1
    f.maximumIntegerDigits = 3
    f.maximumFractionDigits = 0
    return f
}()

/// A `Setting` whose value is a member of the enum `Value`.
public class EnumSetting<Value: Hashable>: Setting<Value> {

    /// List of valid values for this setting. Not all members of the enum are necessary supported.
    public let values: [Value]?

    /// Returns a user-facing description for the given value, when one is available.
    public let formatValue: (Value) -> String?

    public init(
        key: SettingKey<Value>,
        value: Value,
        values: [Value]?,
        formatValue: @escaping (Value) -> String? = { _ in nil },
        validator: @escaping SettingValidator<Value> = { $0 },
        activator: SettingActivator = NullSettingActivator()
    ) {
        self.values = values
        self.formatValue = formatValue
        super.init(
            key: key, value: value,
            validator: { value in
                guard values?.contains(value) ?? true else {
                    return nil
                }
                return validator(value)
            },
            activator: activator
        )
    }
}
