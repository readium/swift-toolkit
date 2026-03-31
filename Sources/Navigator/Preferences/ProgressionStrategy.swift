//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A strategy to increment or decrement a setting.
public protocol ProgressionStrategy: Sendable {
    associatedtype Value

    func increment(_ value: Value) -> Value
    func decrement(_ value: Value) -> Value
}

/// Progression strategy based on a list of preferred values for the setting.
/// Steps MUST be sorted in increasing order.
public final class StepsProgressionStrategy<Value: Comparable & Sendable>: ProgressionStrategy, Sendable {
    private let steps: [Value]

    public init(steps: [Value]) {
        self.steps = steps
    }

    public func increment(_ value: Value) -> Value {
        steps.lastIndex { $0 <= value }
            .flatMap { index in steps.getOrNil(index + 1) }
            ?? value
    }

    public func decrement(_ value: Value) -> Value {
        steps.firstIndex { $0 >= value }
            .flatMap { index in steps.getOrNil(index - 1) }
            ?? value
    }
}

/// Simple progression strategy which increments or decrements the setting by a fixed number.
public final class IncrementProgressionStrategy<Value: Numeric & Sendable>: ProgressionStrategy, Sendable {
    private let increment: Value

    public init(increment: Value) {
        self.increment = increment
    }

    public func increment(_ value: Value) -> Value {
        value + increment
    }

    public func decrement(_ value: Value) -> Value {
        value - increment
    }
}

public final class AnyProgressionStrategy<Value: Sendable>: ProgressionStrategy, Sendable {
    private let _increment: @Sendable (Value) -> Value
    private let _decrement: @Sendable (Value) -> Value

    public init<S: ProgressionStrategy>(_ strategy: S) where S.Value == Value {
        _increment = { strategy.increment($0) }
        _decrement = { strategy.decrement($0) }
    }

    public func increment(_ value: Value) -> Value {
        _increment(value)
    }

    public func decrement(_ value: Value) -> Value {
        _decrement(value)
    }
}

public extension ProgressionStrategy where Value: Sendable {
    func eraseToAnyProgressionStrategy() -> AnyProgressionStrategy<Value> {
        AnyProgressionStrategy(self)
    }
}

public extension AnyProgressionStrategy where Value: Numeric & Sendable {
    static func increment(_ increment: Value) -> AnyProgressionStrategy<Value> {
        IncrementProgressionStrategy(increment: increment).eraseToAnyProgressionStrategy()
    }
}

public extension AnyProgressionStrategy where Value: Comparable & Sendable {
    static func steps(_ steps: Value...) -> AnyProgressionStrategy<Value> {
        StepsProgressionStrategy(steps: steps).eraseToAnyProgressionStrategy()
    }

    static func steps(_ steps: [Value]) -> AnyProgressionStrategy<Value> {
        StepsProgressionStrategy(steps: steps).eraseToAnyProgressionStrategy()
    }
}
