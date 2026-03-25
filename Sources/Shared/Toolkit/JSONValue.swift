//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreFoundation
import Foundation

// MARK: - Core JSONValue

/// A type-safe JSON value.
///
/// This enum is used to represent JSON values in a type-safe way, avoiding the
/// use of `any Sendable` or `Any`. It guarantees that the value is Sendable and
/// Hashable.
public enum JSONValue: Sendable, Hashable, Loggable {
    case null
    case bool(Bool)
    case string(String)
    case integer(Int)
    case double(Double)
    case array([JSONValue])
    case object([String: JSONValue])

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

// MARK: - Decoding Protocols

public protocol JSONValueDecodable {
    init?(json: JSONValue?, warnings: WarningLogger?) throws
}

public extension JSONValueDecodable {
    init?(json: JSONValue?) throws {
        try self.init(json: json, warnings: nil)
    }
}

public extension RawRepresentable where Self: JSONValueDecodable {
    init?(json: JSONValue?, warnings: WarningLogger?) throws {
        guard let json else {
            return nil
        }

        guard let value: Self = json.rawValue() else {
            warnings?.log("Not a valid raw value for \(Self.self)", model: Self.self, source: json)
            return nil
        }

        self = value
    }
}

public extension JSONValue {
    func arrayOf<T: JSONValueDecodable>(warnings: WarningLogger? = nil) -> [T] {
        array?.compactMap { try? T(json: $0, warnings: warnings) } ?? []
    }
}

// MARK: - Encoding Protocols

public protocol JSONValueEncodable {
    var jsonValue: JSONValue { get }
}

public protocol JSONObjectEncodable: JSONValueEncodable {
    var jsonObject: [String: JSONValue] { get }
}

public extension JSONObjectEncodable {
    var jsonValue: JSONValue {
        .object(jsonObject)
    }

    var orNullIfEmpty: JSONValue {
        let object = jsonObject
        return object.isEmpty ? .null : .object(object)
    }
}

// MARK: - Standard Type Encodable Conformance

extension JSONValue: JSONValueEncodable {
    public var jsonValue: JSONValue {
        self
    }

    public init?(_ value: JSONValueEncodable?) {
        guard let value else {
            return nil
        }
        self = value.jsonValue
    }
}

extension String: JSONValueEncodable {
    public var jsonValue: JSONValue {
        .string(self)
    }
}

extension Int: JSONValueEncodable {
    public var jsonValue: JSONValue {
        .integer(self)
    }
}

extension Double: JSONValueEncodable {
    public var jsonValue: JSONValue {
        .double(self)
    }
}

extension NSNumber: JSONValueEncodable {
    public var jsonValue: JSONValue {
        if CFGetTypeID(self) == CFBooleanGetTypeID() {
            return .bool(boolValue)
        }
        if CFNumberIsFloatType(self) {
            return .double(doubleValue)
        }
        if compare(0) == .orderedAscending {
            return .integer(Int(clamping: int64Value))
        } else {
            return .integer(Int(clamping: uint64Value))
        }
    }
}

extension Optional: JSONValueEncodable where Wrapped: JSONValueEncodable {
    public var jsonValue: JSONValue {
        switch self {
        case .none: return .null
        case let .some(wrapped): return wrapped.jsonValue
        }
    }
}

extension Array: JSONValueEncodable where Element: JSONValueEncodable {
    public var jsonValue: JSONValue {
        .array(compactMap(\.jsonValue))
    }
}

public extension [JSONValue] {
    init(_ array: [JSONValueEncodable]) {
        self = array.compactMap(\.jsonValue)
    }
}

public extension [String: JSONValue] {
    init(
        _ dict: [String: JSONValueEncodable],
        filteringNull: Bool = true,
        additional: [String: JSONValueEncodable] = [:]
    ) {
        var dict = dict
            .compactMapValues(\.jsonValue)
            .merging(
                additional.mapValues(\.jsonValue),
                uniquingKeysWith: { current, _ in current }
            )

        if filteringNull {
            dict = dict.filter { _, value in
                if case .null = value { return false }
                return true
            }
        }

        self = dict
    }

    var jsonValue: JSONValue {
        .object(mapValues(\.jsonValue))
    }
}

extension NSNull: JSONValueEncodable {
    public var jsonValue: JSONValue {
        .null
    }
}

// MARK: - ExpressibleByLiteral Conformance

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - Codable Conformance

extension JSONValue: Codable {
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

// MARK: - Dictionary Helpers

public extension [String: JSONValue] {
    mutating func pop(_ key: Key) -> Value? {
        removeValue(forKey: key)
    }
}
