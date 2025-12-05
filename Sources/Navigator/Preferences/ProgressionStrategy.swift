//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A strategy to increment or decrement a setting.
public protocol ProgressionStrategy {
    associatedtype Value

    func increment(_ value: Value) -> Value
    func decrement(_ value: Value) -> Value
}

/// Progression strategy based on a list of preferred values for the setting.
/// Steps MUST be sorted in increasing order.
public class StepsProgressionStrategy<Value: Comparable>: ProgressionStrategy {
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
public class IncrementProgressionStrategy<Value: Numeric>: ProgressionStrategy {
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

public class AnyProgressionStrategy<Value>: ProgressionStrategy {
    private let _increment: (Value) -> Value
    private let _decrement: (Value) -> Value

    public init<S: ProgressionStrategy>(_ strategy: S) where S.Value == Value {
        _increment = strategy.increment
        _decrement = strategy.decrement
    }

    public func increment(_ value: Value) -> Value {
        _increment(value)
    }

    public func decrement(_ value: Value) -> Value {
        _decrement(value)
    }
}

public extension ProgressionStrategy {
    func eraseToAnyProgressionStrategy() -> AnyProgressionStrategy<Value> {
        AnyProgressionStrategy(self)
    }
}

public extension AnyProgressionStrategy where Value: Numeric {
    static func increment(_ increment: Value) -> AnyProgressionStrategy<Value> {
        IncrementProgressionStrategy(increment: increment).eraseToAnyProgressionStrategy()
    }
}

public extension AnyProgressionStrategy where Value: Comparable {
    static func steps(_ steps: Value...) -> AnyProgressionStrategy<Value> {
        StepsProgressionStrategy(steps: steps).eraseToAnyProgressionStrategy()
    }

    static func steps(_ steps: [Value]) -> AnyProgressionStrategy<Value> {
        StepsProgressionStrategy(steps: steps).eraseToAnyProgressionStrategy()
    }
}
