//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Preference {
    /// Creates a new `Preference` object wrapping the receiver and converting
    /// its value `from` and `to` the target type `V`.
    func map<NewValue>(
        from: @escaping (Value) -> NewValue,
        to: @escaping (NewValue) -> Value
    ) -> MappedPreference<Value, NewValue> {
        MappedPreference(original: eraseToAnyPreference(), from: from, to: to)
    }
}

public extension Preference where Value: Hashable {
    /// Creates a new `EnumPreference` object wrapping the receiver with the
    /// provided `supportedValues`.
    func with(supportedValues: Value...) -> PreferenceWithSupportedValues<Value> {
        with(supportedValues: supportedValues)
    }

    /// Creates a new `EnumPreference` object wrapping the receiver with the
    /// provided `supportedValues`.
    func with(supportedValues: [Value]) -> PreferenceWithSupportedValues<Value> {
        PreferenceWithSupportedValues(original: eraseToAnyPreference(), supportedValues: supportedValues)
    }
}

public extension EnumPreference {
    /// Creates a new `EnumPreference` object wrapping the receiver and
    /// converting its value and `supportedValues`, `from` and `to` the target
    /// type `V`.
    func map<NewValue>(
        from: @escaping (Value) -> NewValue,
        to: @escaping (NewValue) -> Value,
        supportedValues: (([Value]) -> [NewValue])? = nil
    ) -> MappedEnumPreference<Value, NewValue> {
        MappedEnumPreference<Value, NewValue>(
            original: eraseToAnyPreference(),
            from: from,
            to: to,
            transformSupportedValues: supportedValues ?? { $0.map(from) }
        )
    }

    /// Creates a new `EnumPreference` object wrapping the receiver with the
    /// provided `supportedValues`.
    func with(supportedValues: Value...) -> MappedEnumPreference<Value, Value> {
        map(supportedValues: { _ in supportedValues })
    }

    /// Creates a new `EnumPreference` object wrapping the receiver with the
    /// provided `supportedValues`.
    func with(supportedValues: [Value]) -> MappedEnumPreference<Value, Value> {
        map(supportedValues: { _ in supportedValues })
    }

    /// Creates a new `EnumPreference` object wrapping the receiver and
    /// transforming its supported values with `transform`.
    func map(supportedValues: @escaping ([Value]) -> [Value]) -> MappedEnumPreference<Value, Value> {
        map(from: { $0 }, to: { $0 }, supportedValues: supportedValues)
    }
}

public extension RangePreference {
    /// Creates a new `RangePreference` object wrapping the receiver and
    /// converting its value and `supportedRange`, `from` and `to` the target
    /// type `Value`.
    ///
    /// The value formatter, or `increment` and `decrement` strategy of the
    /// receiver can be overwritten.
    func map<NewValue>(
        from: @escaping (Value) -> NewValue,
        to: @escaping (NewValue) -> Value,
        supportedRange: ((ClosedRange<Value>) -> ClosedRange<NewValue>)? = nil,
        formatValue: ((NewValue) -> String)? = nil,
        increment: ((AnyRangePreference<NewValue>) -> Void)? = nil,
        decrement: ((AnyRangePreference<NewValue>) -> Void)? = nil
    ) -> MappedRangePreference<Value, NewValue> {
        MappedRangePreference(
            original: eraseToAnyPreference(),
            from: from,
            to: to,
            transformSupportedRange: supportedRange
                ?? { from($0.lowerBound) ... from($0.upperBound) },
            valueFormatter: formatValue,
            incrementer: increment,
            decrementer: decrement
        )
    }

    /// Creates a new `RangePreference` object wrapping the receiver and
    /// transforming its `supportedRange`, or overwriting its `formatValue` or
    /// `increment` and `decrement` strategy.
    func map(
        supportedRange: @escaping (ClosedRange<Value>) -> ClosedRange<Value> = { $0 },
        formatValue: ((Value) -> String)? = nil,
        increment: ((AnyRangePreference<Value>) -> Void)? = nil,
        decrement: ((AnyRangePreference<Value>) -> Void)? = nil
    ) -> MappedRangePreference<Value, Value> {
        MappedRangePreference(
            original: eraseToAnyPreference(),
            from: { $0 }, to: { $0 },
            transformSupportedRange: supportedRange,
            valueFormatter: formatValue,
            incrementer: increment,
            decrementer: decrement
        )
    }

    /// Creates a new `RangePreference` object wrapping the receiver and using
    /// a different supported `range`. A new `progressionStrategy` can be
    /// provided to customize the implementation of increment and decrement.
    func with(
        supportedRange: ClosedRange<Value>? = nil,
        progressionStrategy: AnyProgressionStrategy<Value>
    ) -> MappedRangePreference<Value, Value> {
        map(
            supportedRange: { supportedRange ?? $0 },
            increment: {
                let currentValue = $0.value ?? $0.effectiveValue
                $0.set(progressionStrategy.increment(currentValue))
            },
            decrement: {
                let currentValue = $0.value ?? $0.effectiveValue
                $0.set(progressionStrategy.decrement(currentValue))
            }
        )
    }
}

public class MappedPreference<OldValue, NewValue>: Preference {
    let original: AnyPreference<OldValue>
    let from: (OldValue) -> NewValue
    let to: (NewValue) -> OldValue

    init(
        original: AnyPreference<OldValue>,
        from: @escaping (OldValue) -> NewValue,
        to: @escaping (NewValue) -> OldValue
    ) {
        self.original = original
        self.from = from
        self.to = to
    }

    public var value: NewValue? { original.value.map(from) }
    public var effectiveValue: NewValue { from(original.effectiveValue) }
    public var isEffective: Bool { original.isEffective }

    public func set(_ value: NewValue?) {
        original.set(value.map(to))
    }
}

public class PreferenceWithSupportedValues<Value: Hashable>: MappedPreference<Value, Value>, EnumPreference {
    public let supportedValues: [Value]

    init(original: AnyPreference<Value>, supportedValues: [Value]) {
        self.supportedValues = supportedValues
        super.init(original: original, from: { $0 }, to: { $0 })
    }
}

public class MappedEnumPreference<OldValue: Hashable, NewValue: Hashable>:
    MappedPreference<OldValue, NewValue>, EnumPreference
{
    let originalEnum: AnyEnumPreference<OldValue>
    private let transformSupportedValues: ([OldValue]) -> [NewValue]

    init(
        original: AnyEnumPreference<OldValue>,
        from: @escaping (OldValue) -> NewValue,
        to: @escaping (NewValue) -> OldValue,
        transformSupportedValues: @escaping ([OldValue]) -> [NewValue]
    ) {
        originalEnum = original
        self.transformSupportedValues = transformSupportedValues

        super.init(original: original, from: from, to: to)
    }

    public var supportedValues: [NewValue] {
        transformSupportedValues(originalEnum.supportedValues)
    }

    override public func set(_ value: NewValue?) {
        precondition(value == nil || supportedValues.contains(value!))
        super.set(value)
    }
}

public class MappedRangePreference<OldValue: Comparable, NewValue: Comparable>:
    MappedPreference<OldValue, NewValue>, RangePreference
{
    let originalRange: AnyRangePreference<OldValue>
    private let transformSupportedRange: (ClosedRange<OldValue>) -> ClosedRange<Value>
    private let valueFormatter: ((NewValue) -> String)?
    private let incrementer: ((AnyRangePreference<NewValue>) -> Void)?
    private let decrementer: ((AnyRangePreference<NewValue>) -> Void)?

    init(
        original: AnyRangePreference<OldValue>,
        from: @escaping (OldValue) -> NewValue,
        to: @escaping (NewValue) -> OldValue,
        transformSupportedRange: @escaping (ClosedRange<OldValue>) -> ClosedRange<Value>,
        valueFormatter: ((NewValue) -> String)?,
        incrementer: ((AnyRangePreference<NewValue>) -> Void)?,
        decrementer: ((AnyRangePreference<NewValue>) -> Void)?
    ) {
        originalRange = original
        self.transformSupportedRange = transformSupportedRange
        self.valueFormatter = valueFormatter
        self.incrementer = incrementer
        self.decrementer = decrementer
        super.init(original: original, from: from, to: to)
    }

    public var supportedRange: ClosedRange<NewValue> {
        transformSupportedRange(originalRange.supportedRange)
    }

    override public func set(_ value: NewValue?) {
        super.set(value?.clamped(to: supportedRange))
    }

    public func increment() {
        if let incrementer = incrementer {
            incrementer(eraseToAnyPreference())
        } else {
            originalRange.increment()
        }
    }

    public func decrement() {
        if let decrementer = decrementer {
            decrementer(eraseToAnyPreference())
        } else {
            originalRange.decrement()
        }
    }

    public func format(value: NewValue) -> String {
        if let formatter = valueFormatter {
            return formatter(value)
        } else {
            return originalRange.format(value: to(value))
        }
    }
}
