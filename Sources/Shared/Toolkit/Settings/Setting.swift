//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a single configurable property of a `Configurable` component and holds its current
/// `value`.
public class Setting<Value: Hashable & Codable>: Hashable {

    /// Unique identifier used to serialize `Preferences` to JSON.
    public let key: SettingKey

    /// Current value for this setting.
    public let value: Value

    /// Ensures the validity of a `value`.
    private let validator: SettingValidator<Value>

    /// Ensures that the condition required for this setting to be active are met in the given
    /// `Preferences` – e.g. another setting having a certain preference.
    private let activator: SettingActivator

    public init(
        key: SettingKey,
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
    }

    public static func ==(lhs: Setting, rhs: Setting) -> Bool {
        if lhs === rhs {
            return true
        }

        return type(of: lhs) == type(of: rhs)
            && lhs.key == rhs.key
            && lhs.value == rhs.value
    }
}

public extension Setting: SettingActivator {
    func isActive(with preferences: Preferences) -> Bool {
        activator.isActive(with: preferences)
    }

    func activate(in preferences: inout Preferences) {
        activator.activate(in: &preferences)
    }
}

/// Unique identifier used to serialize `Preferences` to JSON.
public struct SettingKey: Hashable {
    public let id: String

    public init(_ id: String) {
        self.id = id
    }

    public static let backgroundColor = SettingKey("backgroundColor")
    public static let columnCount = SettingKey("columnCount")
    public static let fit = SettingKey("fit")
    public static let fontFamily = SettingKey("fontFamily")
    public static let fontSize = SettingKey("fontSize")
    public static let hyphens = SettingKey("hyphens")
    public static let imageFilter = SettingKey("imageFilter")
    public static let language = SettingKey("language")
    public static let letterSpacing = SettingKey("letterSpacing")
    public static let ligatures = SettingKey("ligatures")
    public static let lineHeight = SettingKey("lineHeight")
    public static let orientation = SettingKey("orientation")
    public static let pageMargins = SettingKey("pageMargins")
    public static let paragraphIndent = SettingKey("paragraphIndent")
    public static let paragraphSpacing = SettingKey("paragraphSpacing")
    public static let publisherStyles = SettingKey("publisherStyles")
    public static let readingProgression = SettingKey("readingProgression")
    public static let scroll = SettingKey("scroll")
    public static let spread = SettingKey("spread")
    public static let textAlign = SettingKey("textAlign")
    public static let textColor = SettingKey("textColor")
    public static let textNormalization = SettingKey("textNormalization")
    public static let theme = SettingKey("theme")
    public static let typeScale = SettingKey("typeScale")
    public static let verticalText = SettingKey("verticalText")
    public static let wordSpacing = SettingKey("wordSpacing")
}

/// Returns a valid value for the given `value`, if possible.
///
/// For example, a range setting will coerce the value to be in the range.
public typealias SettingValidator<Value> = (Value) -> Value?

/// A boolean `Setting`.
public typealias ToggleSetting = Setting<Bool>

/// A `Setting` whose value is constrained to a range.
public class RangeSetting<Value: Comparable & Codable & Hashable>: Setting<Value> {
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
        key: SettingKey,
        value: Value,
        range: ClosedRange<Value>,
        suggestedSteps: [Value]? = nil,
        suggestedIncrement: Value? = nil,
        formatValue: @escaping (Value) -> String = { value in
            if let value = value as? NSNumber {
                return rangeValueFormatter.string(from: value)
            } else {
                return String(describing: value)
            }
        },
        validator: @escaping SettingValidator<Value> = { $0 },
        activator: SettingActivator = NullSettingActivator()
    ) {
        self.range = range
        self.suggestedSteps = suggestedSteps
        self.suggestedIncrement = suggestedIncrement
        self.formatValue = formatValue

        super.init(
            key: key, value: value,
            validator: { value in
                validator(value).flatMap { range.clamp($0) }
            },
            activator: activator
        )
    }
}

private let rangeValueFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 5
}

/// A `RangeSetting` representing a percentage from 0.0 to 1.0.
public class PercentSetting: RangeSetting<Double> {
    public override init(
        key: SettingKey,
        value: Double,
        range: ClosedRange<Double> = 0.0...1.0,
        suggestedSteps: [Double]? = nil,
        suggestedIncrement: Double? = 0.1,
        formatValue: @escaping (Double) -> String = { value in
            percentValueFormatter.string(from: value)
        },
        validator: @escaping SettingValidator<Double> = { $0 },
        activator: SettingActivator = NullSettingActivator()
    ) {
        super.init(
            key: key, value: value, range: range, suggestedSteps: suggestedSteps,
            suggestedIncrement: suggestedIncrement, formatValue: formatValue, validator: validator,
            activator: activator
        )
    }
}

private let percentValueFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.minimumIntegerDigits = 1
    formatter.maximumIntegerDigits = 3
    formatter.maximumFractionDigits = 0
    return formatter
}()

/// A `Setting` whose value is a member of the enum `Value`.
public class EnumSetting<Value: Codable & Hashable>: Setting<Value> {

    /// List of valid values for this setting. Not all members of the enum are necessary supported.
    public let values: [Value]?

    /// Returns a user-facing description for the given value, when one is available.
    public let formatValue: (Value) -> String?

    public init(
        key: SettingKey,
        value: Value,
        values: [Value]?,
        formatValue: @escaping (Value) -> String? = { nil },
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
