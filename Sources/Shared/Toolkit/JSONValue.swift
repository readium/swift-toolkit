//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreFoundation
import Foundation

/// A type-safe representation of a JSON value.
///
/// Use the typed accessors (`bool`, `string`, `integer`, `double`, `array`,
/// `object`) to extract the underlying value.
///
/// `JSONValue` conforms to all `ExpressibleByLiteral` protocols, so you can
/// write JSON structures directly in Swift:
///
/// ```swift
/// let value: JSONValue = ["title": "Moby Dick", "year": 1851]
/// ```
public enum JSONValue: Sendable, Hashable, Loggable {
    /// A JSON `null`.
    case null
    /// A JSON boolean.
    case bool(Bool)
    /// A JSON string.
    case string(String)
    /// A JSON integer number.
    case integer(Int)
    /// A JSON floating-point number.
    case double(Double)
    /// A JSON array.
    case array([JSONValue])
    /// A JSON object.
    case object([String: JSONValue])

    /// Converts a `Any` – for example returned by `JSONSerialization` – into a
    /// type-safe `JSONValue`.
    public init?(_ any: Any?) {
        guard let any = any else { return nil }

        switch any {
        case is NSNull:
            self = .null
        case let number as NSNumber:
            self = number.jsonValue
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(array.compactMap { JSONValue($0) })
        case let dict as [String: Any]:
            self = .object(dict.compactMapValues { JSONValue($0) })
        default:
            return nil
        }
    }

    /// Returns the value as a standard Swift / Foundation type.
    ///
    /// This is useful for interoperability with APIs that expect untyped values
    /// such as `JSONSerialization`.
    ///
    /// `null` becomes `NSNull`.
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

    /// Returns the associated `Bool` if this value is `.bool`, otherwise `nil`.
    public var bool: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }

    /// Returns the associated `String` if this value is `.string`, otherwise
    /// `nil`.
    public var string: String? {
        if case let .string(v) = self { return v }
        return nil
    }

    /// Returns the associated `Int` if this value is `.integer`, otherwise
    /// `nil`.
    public var integer: Int? {
        if case let .integer(v) = self { return v }
        return nil
    }

    /// Returns the numeric value as a `Double`.
    ///
    /// Returns the associated value for `.double`, or the integer value
    /// promoted to `Double` for `.integer`. Returns `nil` for all other cases.
    public var double: Double? {
        if case let .double(v) = self { return v }
        if case let .integer(v) = self { return Double(v) }
        return nil
    }

    /// Returns the associated array if this value is `.array`, otherwise `nil`.
    public var array: [JSONValue]? {
        if case let .array(v) = self { return v }
        return nil
    }

    /// Returns the associated dictionary if this value is `.object`, otherwise
    /// `nil`.
    public var object: [String: JSONValue]? {
        if case let .object(v) = self { return v }
        return nil
    }
}

// MARK: - Errors

/// Errors thrown during JSON parsing and serialization.
public enum JSONError: Error {
    /// The JSON data could not be parsed into the expected type.
    case parsing(Any.Type, cause: Error? = nil)
    /// The value could not be serialized to JSON.
    case serializing(Any.Type, cause: Error? = nil)
}

// MARK: - Decoding Protocols

/// A type that can be decoded from a `JSONValue`.
///
/// Conform to this protocol to enable decoding your type from a JSON value.
///
/// Return `nil` (not throw) when the value is absent or of the wrong type.
/// Throw only for structural errors that indicate malformed data.
///
/// Use `warnings` to report non-fatal issues while parsing the JSON.
public protocol JSONValueDecodable {
    init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws
}

public extension JSONValueDecodable {
    /// Convenience initializer that discards warnings.
    init?<T: JSONValueEncodable>(json: T?) throws {
        try self.init(json: json, warnings: nil)
    }
}

/// Provides a default `JSONValueDecodable` implementation for
/// `RawRepresentable` types whose `RawValue` is itself decodable from a
/// `JSONValue`.
///
/// Enums with a `String` or `Int` raw value get JSON decoding for free:
///
/// ```swift
/// enum Layout: String { case reflowable, fixed }
/// let layout = try Layout(json: jsonObject["layout"], warnings: warnings)
/// ```
public extension RawRepresentable where RawValue: JSONValueDecodable {
    init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }

        guard let value: Self = json.decode() else {
            warnings?.log("Not a valid raw value for \(Self.self)", model: Self.self, source: json)
            return nil
        }

        self = value
    }
}

public extension JSONValue {
    /// Decodes a `RawRepresentable` value from this value.
    ///
    /// Invalid raw values are silently skipped.
    func decode<T: RawRepresentable>() -> T? {
        guard let rawValue = any as? T.RawValue else {
            return nil
        }

        return T(rawValue: rawValue)
    }

    /// Decodes a `JSONValueDecodable` value from this value.
    ///
    /// Returns `nil` if the value cannot be decoded as `T`.
    /// Throws only for structural errors that indicate malformed data.
    func decode<T: JSONValueDecodable>(
        warnings: WarningLogger? = nil
    ) throws -> T? {
        try T(json: self, warnings: warnings)
    }

    /// Decodes an array of `T` from this value.
    ///
    /// - If this value is `.array`, each element is decoded as `T`; invalid
    ///   elements are silently skipped.
    /// - If `allowingSingle` is `true` and this value is not an array, it is
    ///   treated as a single-element array and decoded as `T`.
    /// - Returns an empty array for `.null` or any non-array value when
    ///   `allowingSingle` is `false`.
    func decode<T: JSONValueDecodable>(
        allowingSingle: Bool = false,
        warnings: WarningLogger? = nil
    ) -> [T] {
        switch self {
        case let .array(array):
            return array.decode(warnings: warnings)
        default:
            if allowingSingle {
                return Array(ofNotNil: try? T(json: self, warnings: warnings))
            }
            return []
        }
    }

    /// Decodes an array of `RawRepresentable` values from this value.
    ///
    /// Invalid raw values are silently skipped.
    func decode<T: RawRepresentable>(allowingSingle: Bool = false) -> [T] {
        if allowingSingle, let value: T = decode() {
            return [value]
        }

        return array?.compactMap { $0.decode() } ?? []
    }
}

public extension [JSONValue] {
    /// Decodes each element as `T`, silently skipping elements that fail to
    /// decode.
    func decode<T: JSONValueDecodable>(warnings: WarningLogger? = nil) -> [T] {
        compactMap { try? T(json: $0, warnings: warnings) }
    }
}

// MARK: - Encoding Protocols

/// A type that can be encoded to a `JSONValue`.
public protocol JSONValueEncodable {
    /// The `JSONValue` representation of this value.
    var jsonValue: JSONValue { get }
}

extension JSONValue: JSONValueEncodable {
    public var jsonValue: JSONValue {
        self
    }
}

extension JSONValue: JSONValueDecodable {
    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let value = json?.jsonValue else { return nil }
        self = value
    }
}

/// A type that encodes to a JSON object (`[String: JSONValue]`).
public protocol JSONObjectEncodable: JSONValueEncodable {
    /// The JSON object representation of this value.
    var jsonObject: [String: JSONValue] { get }
}

public extension JSONObjectEncodable {
    /// Returns `.object(jsonObject)`.
    var jsonValue: JSONValue {
        .object(jsonObject)
    }

    /// Returns `.object(jsonObject)` if non-empty, or `.null` if empty.
    ///
    /// Useful when serializing optional nested objects: the result can be
    /// inserted into a parent dictionary and will be filtered out automatically
    /// when `filteringNull: true` (the default).
    var orNullIfEmpty: JSONValue {
        let object = jsonObject
        return object.isEmpty ? .null : .object(object)
    }
}

/// Provides a `jsonValue` for any `RawRepresentable` whose `RawValue` conforms
/// to `JSONValueEncodable`.
///
/// Enums with a `String` or `Int` raw value get JSON encoding for free:
///
/// ```swift
/// enum Layout: String { case reflowable, fixed }
/// let value = Layout.reflowable.jsonValue  // .string("reflowable")
/// ```
public extension RawRepresentable where RawValue: JSONValueEncodable {
    var jsonValue: JSONValue {
        rawValue.jsonValue
    }
}

// MARK: - Serialization

public extension JSONValueEncodable {
    /// Serializes this value to a JSON string.
    ///
    /// Keys are sorted and slashes are not escaped, producing deterministic
    /// output suitable for comparison and storage.
    func jsonString() throws -> String {
        let data = try jsonData()
        guard let string = String(data: data, encoding: .utf8) else {
            throw JSONError.serializing(Self.self, cause: nil)
        }
        return string
    }

    /// Serializes this value to JSON data.
    ///
    /// Keys are sorted and slashes are not escaped, producing deterministic
    /// output suitable for comparison and storage.
    func jsonData() throws -> Data {
        do {
            return try JSONSerialization.data(
                withJSONObject: jsonValue.any,
                options: [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
            )
        } catch {
            throw JSONError.serializing(Self.self, cause: error)
        }
    }
}

// MARK: - Deserialization

public extension JSONValueDecodable {
    /// Parses a value of this type from JSON-encoded data.
    ///
    /// Throws `JSONError.parsing` if the data is not valid JSON or cannot be
    /// decoded as `Self`.
    init(jsonData: Data, warnings: WarningLogger? = nil) throws {
        let any: Any
        do {
            any = try JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed)
        } catch {
            throw JSONError.parsing(Self.self, cause: error)
        }
        guard let jsonValue = JSONValue(any) else {
            throw JSONError.parsing(Self.self)
        }
        guard let decoded = try Self(json: jsonValue, warnings: warnings) else {
            throw JSONError.parsing(Self.self)
        }
        self = decoded
    }

    /// Parses a value of this type from a JSON string.
    ///
    /// Throws `JSONError.parsing` if the string is not valid JSON, cannot be
    /// encoded as UTF-8, or cannot be decoded as `Self`.
    init(jsonString: String, warnings: WarningLogger? = nil) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw JSONError.parsing(Self.self)
        }
        try self.init(jsonData: data, warnings: warnings)
    }
}

// MARK: - Standard Type Conformances

extension String: JSONValueEncodable, JSONValueDecodable {
    public var jsonValue: JSONValue {
        .string(self)
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let string = json?.jsonValue.string else { return nil }
        self = string
    }
}

extension Bool: JSONValueEncodable, JSONValueDecodable {
    public var jsonValue: JSONValue {
        .bool(self)
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let bool = json?.jsonValue.bool else { return nil }
        self = bool
    }
}

extension Int: JSONValueEncodable, JSONValueDecodable {
    public var jsonValue: JSONValue {
        .integer(self)
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let integer = json?.jsonValue.integer else { return nil }
        self = integer
    }
}

extension UInt64: JSONValueEncodable {
    /// Encodes as `.integer`, clamping to `Int.max` if the value exceeds it.
    public var jsonValue: JSONValue {
        .integer(Int(clamping: self))
    }
}

extension Double: JSONValueEncodable, JSONValueDecodable {
    public var jsonValue: JSONValue {
        .double(self)
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let double = json?.jsonValue.double else { return nil }
        self = double
    }
}

extension Optional: JSONValueEncodable where Wrapped: JSONValueEncodable {
    /// Encodes `.none` as `.null` and `.some(wrapped)` as `wrapped.jsonValue`.
    public var jsonValue: JSONValue {
        switch self {
        case .none: return .null
        case let .some(wrapped): return wrapped.jsonValue
        }
    }
}

extension Array: JSONValueEncodable where Element: JSONValueEncodable {
    public var jsonValue: JSONValue {
        .array(map(\.jsonValue))
    }

    /// Returns `.array(...)` if non-empty, or `.null` if empty.
    ///
    /// Useful when serializing optional arrays into a parent JSON object with
    /// `filteringNull: true` (the default).
    public var orNullIfEmpty: JSONValue {
        isEmpty ? .null : .array(map(\.jsonValue))
    }
}

extension [String: JSONValue]: JSONObjectEncodable, JSONValueEncodable {
    /// Creates a `[String: JSONValue]` from a dictionary of encodable values.
    ///
    /// - Parameters:
    ///   - dict: The primary key-value pairs to include.
    ///   - filteringNull: When `true` (the default), entries whose value
    ///     encodes to `.null` are removed from the result.
    ///   - adding: Extra key-value pairs merged into the result. Keys
    ///     already present in `dict` are not overwritten.
    public init(
        _ dict: [String: JSONValueEncodable],
        filteringNull: Bool = true,
        adding: [String: JSONValueEncodable] = [:]
    ) {
        var dict = dict
            .mapValues(\.jsonValue)
            .merging(
                adding.mapValues(\.jsonValue),
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

    public var jsonObject: [String: JSONValue] {
        mapValues(\.jsonValue)
    }
}

// MARK: - Objective-C Type Conformances

extension NSNumber: JSONValueEncodable {
    /// Encodes the number with type fidelity.
    ///
    /// Uses Core Foundation introspection to preserve the original numeric
    /// kind:
    /// - `CFBoolean` → `.bool`
    /// - Float types → `.double`
    /// - Negative integers → `.integer` (clamped via `Int64`)
    /// - Non-negative integers → `.integer` (clamped via `UInt64`)
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

// MARK: - Dictionary Helpers

package extension [String: JSONValue] {
    /// Removes the value for `key` and returns it, or returns `nil` if absent.
    ///
    /// Useful when consuming known keys from a JSON object while collecting
    /// the remainder into an `otherMetadata`-style catch-all:
    ///
    /// ```swift
    /// var json = jsonObject
    /// let title = json.pop("title")?.string
    /// let otherMetadata = json   // everything that wasn't explicitly consumed
    /// ```
    mutating func pop(_ key: Key) -> Value? {
        removeValue(forKey: key)
    }
}

// MARK: - Parsing Extensions

public extension JSONValue {
    /// Parses an ISO 8601 date from a `.string` value.
    ///
    /// Returns `nil` if this value is not a `.string` or if the string is not
    /// a valid ISO 8601 date.
    var date: Date? {
        string?.dateFromISO8601
    }

    /// Extracts a non-negative number of type `T`.
    ///
    /// Returns `nil` if:
    /// - The value is not `.integer` or `.double`.
    /// - The number is negative.
    /// - The number cannot be represented exactly as `T` (e.g., a fractional
    ///   double when `T` is `Int`).
    func nonNegative<T: Comparable & Numeric>() -> T? {
        switch self {
        case let .integer(value):
            guard value >= 0 else { return nil }
            return T(exactly: value)
        case let .double(value):
            guard value >= 0 else { return nil }
            if let t = value as? T { return t }
            if let t = Float(value) as? T { return t }
            if let t = UInt64(exactly: value) as? T { return t }
            return Int64(exactly: value).flatMap { T(exactly: $0) }
        default:
            return nil
        }
    }
}
