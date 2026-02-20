//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Wraps a dictionary parsed from a JSON string.
/// This is a trick to keep the Web Publication structs equatable without having to override `==` and compare all the other properties.
public struct JSONDictionary: Sendable {
    public typealias Key = String
    public typealias Value = JSONValue
    public typealias Wrapped = [Key: Value]

    public var json: Wrapped

    public init() {
        json = [:]
    }

    public init?(_ json: Any?) {
        guard let value = JSONValue(json),
              case let .object(dict) = value
        else {
            return nil
        }
        self.json = dict
    }

    public mutating func pop(_ key: Key) -> Value? {
        json.removeValue(forKey: key)
    }
}

extension JSONDictionary: Collection {
    public typealias Index = DictionaryIndex<Key, Value>
    public typealias Element = (key: Key, value: Value)

    public var startIndex: Index {
        json.startIndex
    }

    public var endIndex: Index {
        json.endIndex
    }

    public subscript(index: Index) -> Iterator.Element {
        json[index]
    }

    public func index(after i: Index) -> Index {
        json.index(after: i)
    }
}

extension JSONDictionary: Equatable {}

extension JSONDictionary: Hashable {}

// MARK: - JSON Parsing

/// enum Example: String {
///     case hello
/// }
/// let json = ["key": "hello"]
/// let value: Example? = parseRaw(json["key"])
public func parseRaw<T: RawRepresentable>(_ json: JSONValue?) -> T? {
    guard let json = json, let rawValue = json.any as? T.RawValue else {
        return nil
    }
    return T(rawValue: rawValue)
}

public func parseRaw<T: RawRepresentable>(_ json: Any?) -> T? {
    parseRaw((json as? JSONValue) ?? JSONValue(json))
}

/// let json = [
///    "multiple": ["hello", "world"]
///    "single": "hello",
/// ]
/// let values1: [String] = parseArray(json["multiple"])
/// let values2: [String] = parseArray(json["single"], allowingSingle: true)
///
/// - Parameter allowingSingle: If true, then allows the parsing of both a single value and an array.
public func parseArray<T>(_ json: JSONValue?, allowingSingle: Bool = false) -> [T] {
    guard let json = json else {
        return []
    }

    switch json {
    case let .array(arr):
        if T.self == JSONValue.self {
            return arr as! [T]
        }
        return arr.compactMap { $0.any as? T }
    default:
        if allowingSingle {
            if T.self == JSONValue.self {
                return [json] as! [T]
            }
            if let val = json.any as? T {
                return [val]
            }
        }
        return []
    }
}

public func parseArray<T>(_ json: Any?, allowingSingle: Bool = false) -> [T] {
    parseArray((json as? JSONValue) ?? JSONValue(json), allowingSingle: allowingSingle)
}

/// Casting to Double loses precision and fails with integers, eg. json["key"] as? Double.
public func parseDouble(_ json: Any?) -> Double? {
    let json = (json as? JSONValue) ?? JSONValue(json)
    return json?.double
}

/// Parses a numeric value, but returns nil if it is not a positive number.
public func parsePositive<T: Comparable & Numeric>(_ json: Any?) -> T? {
    let json = (json as? JSONValue) ?? JSONValue(json)
    guard let number = json?.any as? T, number >= 0 else {
        return nil
    }
    return number
}

public func parsePositiveDouble(_ json: Any?) -> Double? {
    guard let double = parseDouble(json), double >= 0 else {
        return nil
    }
    return double
}

public func parseDate(_ json: Any?) -> Date? {
    let json = (json as? JSONValue) ?? JSONValue(json)
    return json?.string?.dateFromISO8601
}

/// Returns the given JSON object after removing any key with NSNull (or JSONValue.null) value.
/// To be used with `encodeIfX` functions for more compact serialization code.
public func makeJSON(_ object: [String: JSONValue], additional: [String: JSONValue] = [:]) -> [String: JSONValue] {
    object.filter { _, value in
        if case .null = value { return false }
        return true
    }.merging(additional, uniquingKeysWith: { current, _ in current })
}

/// Returns the value if not nil, or JSONValue.null.
public func encodeIfNotNil(_ value: Any?) -> JSONValue {
    guard let value = value, let json = JSONValue(value) else {
        return .null
    }
    return json
}

/// Returns the raw representable's raw value if not nil, or JSONValue.null. To be used with optional Enum.
public func encodeRawIfNotNil<T: RawRepresentable>(_ value: T?) -> JSONValue {
    guard let raw = value?.rawValue, let json = JSONValue(raw) else {
        return .null
    }
    return json
}

/// Returns the collection if not empty, or JSONValue.null.
public func encodeIfNotEmpty(_ value: Any?) -> JSONValue {
    guard let value = value, let json = JSONValue(value) else {
        return .null
    }

    switch json {
    case let .array(arr):
        return arr.isEmpty ? .null : json
    case let .object(obj):
        return obj.isEmpty ? .null : json
    case let .string(s):
        return s.isEmpty ? .null : json
    default:
        return json
    }
}
