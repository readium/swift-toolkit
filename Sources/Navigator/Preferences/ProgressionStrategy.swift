//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

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

/// Simple progression strategy which increments or decrements the setting by a
/// fixed number.
///
/// `Double` results are rounded to 4 decimal places past the first significant
/// digit of the increment (e.g. 5 decimal places for `0.1` or `0.25`), to drop
/// the residue of the binary floating-point arithmetic (e.g. `0.2 + 0.1` gives
/// `0.3` instead of `0.30000000000000004`). Other types, such as `Float` or
/// `CGFloat`, are not rounded.
public final class IncrementProgressionStrategy<Value: Numeric & Sendable>: ProgressionStrategy, Sendable {
    private let increment: Value

    public init(increment: Value) {
        self.increment = increment
    }

    public func increment(_ value: Value) -> Value {
        roundResidue(value + increment)
    }

    public func decrement(_ value: Value) -> Value {
        roundResidue(value - increment)
    }

    private func roundResidue(_ value: Value) -> Value {
        guard
            let result = value as? Double,
            let step = increment as? Double,
            step.isNormal
        else {
            return value
        }

        // Keeps 4 decimal places past the first significant digit of the step.
        let scale = pow(10, 4 - log10(step.magnitude).rounded(.down))
        // Adding zero turns -0.0 into 0.0.
        return ((result * scale).rounded() / scale + 0) as? Value ?? value
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
