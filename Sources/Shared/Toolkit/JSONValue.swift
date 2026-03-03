//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreFoundation
import Foundation

/// A type-safe JSON value.
///
/// This enum is used to represent JSON values in a type-safe way, avoiding the
/// use of `any Sendable` or `Any`. It guarantees that the value is Sendable and
/// Hashable.
@_spi(Internal) public enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case string(String)
    case integer(Int)
    case double(Double)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Initializes a `JSONValue` from an `Any` value.
    ///
    /// This initializer attempts to convert the given value to a `JSONValue`.
    /// It handles nested arrays and dictionaries recursively.
    public init?(_ value: Any?) {
        guard let value = value else {
            return nil
        }

        if let value = value as? JSONValue {
            self = value
            return
        }

        // Fast path for typed collections
        if let object = value as? [String: JSONValue] {
            self = .object(object)
            return
        }
        if let array = value as? [JSONValue] {
            self = .array(array)
            return
        }

        // Check for specific types
        if let string = value as? String {
            self = .string(string)
            return
        }

        // On platforms with CoreFoundation (Apple), NSNumber bridges from Bool, Int, Double.
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
                return
            }
            if CFNumberIsFloatType(number) {
                self = .double(number.doubleValue)
                return
            }
            if let int = Int(exactly: number) {
                self = .integer(int)
            } else {
                self = .double(number.doubleValue)
            }
            return
        }

        // Fallback for if value isn't NSNumber
        if let bool = value as? Bool {
            self = .bool(bool)
        } else if let int = value as? Int {
            self = .integer(int)
        } else if let uint = value as? UInt64 {
            if let int = Int(exactly: uint) {
                self = .integer(int)
            } else {
                self = .double(Double(uint))
            }
        } else if let double = value as? Double {
            self = .double(double)
        } else if let array = value as? [Any] {
            self = .array(array.compactMap { JSONValue($0) })
        } else if let dict = value as? [String: Any] {
            var object: [String: JSONValue] = [:]
            for (key, val) in dict {
                if let jsonVal = JSONValue(val) {
                    object[key] = jsonVal
                }
            }
            self = .object(object)
        } else if value is NSNull {
            self = .null
        } else {
            return nil
        }
    }

    /// Returns the raw value as `Any`.
    ///
    /// This property is useful for interoperability with APIs that expect
    /// standard Swift types (e.g., `JSONSerialization`).
    public var any: Any {
        switch self {
        case .null:
            return NSNull()
        case let .bool(value):
            return value
        case let .string(value):
            return value
        case let .integer(value):
            return value
        case let .double(value):
            return value
        case let .array(value):
            return value.map(\.any)
        case let .object(value):
            return value.mapValues(\.any)
        }
    }

    public var bool: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }

    public var string: String? {
        if case let .string(v) = self { return v }
        return nil
    }

    public var integer: Int? {
        if case let .integer(v) = self { return v }
        return nil
    }

    public var uint64: UInt64? {
        if case let .integer(v) = self { return UInt64(exactly: v) }
        if case let .double(v) = self { return UInt64(exactly: v) }
        return nil
    }

    public var double: Double? {
        if case let .double(v) = self { return v }
        if case let .integer(v) = self { return Double(v) }
        return nil
    }

    public var array: [JSONValue]? {
        if case let .array(v) = self { return v }
        return nil
    }

    public var object: [String: JSONValue]? {
        if case let .object(v) = self { return v }
        return nil
    }
}

// MARK: - ExpressibleByLiteral Conformance

@_spi(Internal) extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

@_spi(Internal) extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

@_spi(Internal) extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

@_spi(Internal) extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

@_spi(Internal) extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

@_spi(Internal) extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

@_spi(Internal) extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - Codable Conformance

@_spi(Internal) extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Always try to decode Nil first
        if container.decodeNil() {
            self = .null
            return
        }

        // Attempt to decode boolean
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        // Attempt to decode Int
        if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
            return
        }

        // Attempt to decode floating point numbers
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }

        // Attempt to decode string
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        // Attempt to decode array
        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }

        // Attempt to decode object
        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }

        // If all attempts fail, throw an error
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Data cannot be decoded as a valid JSONValue."
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .integer(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}
