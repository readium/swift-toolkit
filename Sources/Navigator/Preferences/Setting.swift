//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/*
/// Represents a single configurable property of a `Configurable` component and holds its current
/// `value`.
public class Setting<Value: Hashable> {

    /// Unique identifier used to serialize `Preferences` to JSON.
    public let key: SettingKey<Value>

    /// Current value for this setting.
    public let value: Value

    /// Ensures that the condition required for this setting to be active are met in the given
    /// `Preferences` – e.g. another setting having a certain preference.
    private let activator: SettingActivator

    public init(
        key: SettingKey<Value>,
        value: Value,
        activator: SettingActivator = NullSettingActivator()
    ) {
        self.key = key
        self.value = value
        self.activator = activator
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

/// A `Setting` whose value is constrained to a range.
public class RangeSetting<Value: Comparable & Hashable>: Setting<Value> {
    /// The valid range for the setting value.
    public let range: ClosedRange<Value>

    /// Suggested strategy to increment or decrement a value.
    public let suggestedProgression: AnyProgressionStrategy<Value>?

    /// Returns a user-facing description for the given value. This can be used to format the value
    /// unit.
    public let formatValue: (Value) -> String

    public init(
        key: SettingKey<Value>,
        value: Value,
        range: ClosedRange<Value>,
        suggestedProgression: AnyProgressionStrategy<Value>? = nil,
        formatValue: ((Value) -> String)? = nil,
        activator: SettingActivator = NullSettingActivator()
    ) {
        precondition(range.contains(value))

        self.range = range
        self.suggestedProgression = suggestedProgression
        self.formatValue = formatValue ?? { value in
            (value as? NSNumber)
                .flatMap { rangeValueFormatter.string(from: $0) }
                ?? String(describing: value)
        }

        super.init(key: key, value: value, activator: activator)
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
    public init(
        key: SettingKey<Double>,
        value: Double,
        range: ClosedRange<Double> = 0.0...1.0,
        suggestedProgression: AnyProgressionStrategy<Double> = IncrementProgressionStrategy(increment: 0.1).eraseToAnyProgressionStrategy(),
        formatValue: ((Double) -> String)? = nil,
        activator: SettingActivator = NullSettingActivator()
    ) {
        super.init(
            key: key, value: value, range: range,
            suggestedProgression: suggestedProgression,
            formatValue: formatValue ?? { value in
                percentValueFormatter.string(from: value as NSNumber)
                    ?? String(format: "%.0f%%", value * 100)
            },
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
        activator: SettingActivator = NullSettingActivator()
    ) {
        precondition(values?.contains(value) ?? true)

        self.values = values
        self.formatValue = formatValue
        super.init(key: key, value: value, activator: activator)
    }
}

*/
