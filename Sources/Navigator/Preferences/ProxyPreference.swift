//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public class ProxyPreference<Value>: Preference {
    private let _value: () -> Value?
    private let _effectiveValue: () -> Value
    private let _isEffective: () -> Bool
    private let _set: (Value?) -> Void

    init(
        value: @escaping () -> Value?,
        effectiveValue: @escaping () -> Value,
        isEffective: @escaping () -> Bool,
        set: @escaping (Value?) -> Void
    ) {
        _value = value
        _effectiveValue = effectiveValue
        _isEffective = isEffective
        _set = set
    }

    public var value: Value? {
        _value()
    }

    public var effectiveValue: Value {
        _effectiveValue()
    }

    public var isEffective: Bool {
        _isEffective()
    }

    public func set(_ value: Value?) {
        _set(value)
    }
}

public class ProxyEnumPreference<Value: Hashable>: ProxyPreference<Value>, EnumPreference {
    public let supportedValues: [Value]

    init(
        value: @escaping () -> Value?,
        effectiveValue: @escaping () -> Value,
        isEffective: @escaping () -> Bool,
        set: @escaping (Value?) -> Void,
        supportedValues: [Value]
    ) {
        self.supportedValues = supportedValues
        super.init(value: value, effectiveValue: effectiveValue, isEffective: isEffective, set: set)
    }

    override public func set(_ value: Value?) {
        precondition(value == nil || supportedValues.contains(value!))
        super.set(value)
    }
}

public class ProxyRangePreference<Value: Comparable>: ProxyPreference<Value>, RangePreference {
    public var supportedRange: ClosedRange<Value>
    private let progressionStrategy: AnyProgressionStrategy<Value>
    private let valueFormatter: (Value) -> String

    init(
        value: @escaping () -> Value?,
        effectiveValue: @escaping () -> Value,
        isEffective: @escaping () -> Bool,
        set: @escaping (Value?) -> Void,
        supportedRange: ClosedRange<Value>,
        progressionStrategy: AnyProgressionStrategy<Value>,
        format: @escaping (Value) -> String
    ) {
        self.supportedRange = supportedRange
        self.progressionStrategy = progressionStrategy
        valueFormatter = format
        super.init(value: value, effectiveValue: effectiveValue, isEffective: isEffective, set: set)
    }

    override public func set(_ value: Value?) {
        super.set(value?.clamped(to: supportedRange))
    }

    public func format(value: Value) -> String {
        valueFormatter(value)
    }

    public func increment() {
        let currentValue = value ?? effectiveValue
        set(progressionStrategy.increment(currentValue))
    }

    public func decrement() {
        let currentValue = value ?? effectiveValue
        set(progressionStrategy.decrement(currentValue))
    }
}
