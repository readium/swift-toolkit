//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Smart pointer protecting concurrent access to its memory to avoid data races.
///
/// This is also a property wrapper, which makes it easy to use as:
/// ```
/// @Atomic var data: Int
/// ```
///
/// The property becomes read-only, to prevent a common error when modifying the property using its
/// previous value. For example:
/// ```
/// data += 1
/// ```
/// This is not safe, because it's actually two operations: a read and a write. The value might have changed
/// between the moment you read it and when you write the result of incrementing the value.
///
/// Instead, you must use `write()` to mutate the property:
/// ```
/// $data.write { value in
///     value += 1
/// }
/// ```
@propertyWrapper
public final class Atomic<Value> {
    private var value: Value

    /// Queue used to protect accesses to `value`.
    ///
    /// We could use a serial queue but that would impact performances as concurrent reads would not be
    /// possible. To make sure we don't get data races, writes are done using a `.barrier` flag.
    private let queue = DispatchQueue(label: "org.readium.swift-toolkit.Atomic", attributes: .concurrent)

    public init(wrappedValue value: Value) {
        self.value = value
    }

    public var wrappedValue: Value {
        get { read() }
        set { fatalError("Use $property.write { $0 = ... } to mutate this property") }
    }

    public var projectedValue: Atomic<Value> {
        self
    }

    /// Reads the current value synchronously.
    public func read() -> Value {
        queue.sync {
            value
        }
    }

    /// Reads the current value asynchronously.
    public func read(completion: @escaping (Value) -> Void) {
        queue.async {
            completion(self.value)
        }
    }

    /// Writes the value synchronously in a safe way.
    public func write(_ changes: (inout Value) -> Void) {
        // The `barrier` flag here guarantees that we will never have a
        // concurrent read on `value` while we are modifying it. This prevents
        // a data race.
        queue.sync(flags: .barrier) {
            changes(&value)
        }
    }
}
