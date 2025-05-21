//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Wraps a dictionary parsed from a JSON string.
/// This is a trick to keep the Web Publication structs equatable without having to override `==` and compare all the other properties.
public struct JSONDictionary: Sendable {
    public typealias Key = String
    public typealias Value = Sendable
    public typealias Wrapped = [Key: Value]

    public var json: Wrapped

    public init() {
        json = [:]
    }

    public init?(_ json: Any?) {
        guard let json = json as? Wrapped else {
            return nil
        }
        self.json = json
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

extension JSONDictionary: Equatable {
    public static func == (lhs: JSONDictionary, rhs: JSONDictionary) -> Bool {
        let l = try? JSONSerialization.data(withJSONObject: lhs.json, options: [.sortedKeys])
        let r = try? JSONSerialization.data(withJSONObject: rhs.json, options: [.sortedKeys])
        return l == r
    }
}

extension JSONDictionary: Hashable {
    public func hash(into hasher: inout Hasher) {
        let jsonString = (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]))
            .map { String(data: $0, encoding: .utf8) }
        hasher.combine(jsonString ?? "{}")
    }
}

// MARK: - JSON Parsing

/// enum Example: String {
///     case hello
/// }
/// let json = ["key": "hello"]
/// let value: Example? = parseRaw(json["key"])
public func parseRaw<T: RawRepresentable>(_ json: Any?) -> T? {
    guard let rawValue = json as? T.RawValue else {
        return nil
    }
    return T(rawValue: rawValue)
}

/// let json = [
///    "multiple": ["hello", "world"]
///    "single": "hello",
/// ]
/// let values1: [String] = parseArray(json["multiple"])
/// let values2: [String] = parseArray(json["single"], allowingSingle: true)
///
/// - Parameter allowingSingle: If true, then allows the parsing of both a single value and an array.
public func parseArray<T>(_ json: Any?, allowingSingle: Bool = false) -> [T] {
    if let values = json as? [T] {
        return values
    } else if allowingSingle, let value = json as? T {
        return [value]
    } else {
        return []
    }
}

/// Casting to Double loses precision and fails with integers, eg. json["key"] as? Double.
public func parseDouble(_ json: Any?) -> Double? {
    (json as? NSNumber)?.doubleValue
}

/// Parses a numeric value, but returns nil if it is not a positive number.
public func parsePositive<T: Comparable & Numeric>(_ json: Any?) -> T? {
    guard let number = json as? T, number >= 0 else {
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
    (json as? String)?.dateFromISO8601
}

/// Returns the given JSON object after removing any key with NSNull value.
/// To be used with `encodeIfX` functions for more compact serialization code.
public func makeJSON(_ object: JSONDictionary.Wrapped, additional: JSONDictionary.Wrapped = [:]) -> JSONDictionary.Wrapped {
    object.filter { _, value in
        !(value is NSNull)
    }.merging(additional, uniquingKeysWith: { current, _ in current })
}

/// Returns the value if not nil, or NSNull.
public func encodeIfNotNil(_ value: Any?) -> Any {
    value ?? NSNull()
}

/// Returns the raw representable's raw value if not nil, or NSNull. To be used with optional Enum.
public func encodeRawIfNotNil<T: RawRepresentable>(_ value: T?) -> Any {
    value?.rawValue ?? NSNull()
}

/// Returns the collection if not empty, or NSNull.
public func encodeIfNotEmpty<T: Collection>(_ collection: T?) -> Any {
    guard let collection = collection else {
        return NSNull()
    }
    return collection.isEmpty ? NSNull() : collection
}
