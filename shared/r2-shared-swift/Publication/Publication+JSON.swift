//
//  Publication+JSON.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


enum JSONError: LocalizedError {
    case parsing(Any.Type)

    var errorDescription: String? {
        switch self {
        case .parsing(let type):
            return R2SharedLocalizedString("JSONError.parsing", "\(type)")
        }
    }
    
}


/// Wraps a dictionary parsed from a JSON string.
/// This is a trick to keep the Web Publication structs equatable without having to override `==` and compare all the other properties.
struct JSONDictionary {
    
    var json: [String: Any]
    
    init() {
        self.json = [:]
    }
    
    init?(_ json: Any?) {
        guard let json = json as? [String: Any] else {
            return nil
        }
        self.json = json
    }
    
    mutating func pop(_ key: String) -> Any? {
        return json.removeValue(forKey: key)
    }
    
}

extension JSONDictionary: Collection {
    typealias Index = DictionaryIndex<String, Any>
    typealias Element = (key: String, value: Any)

    var startIndex: Index {
        return json.startIndex
    }
    
    var endIndex: Index {
        return json.endIndex
    }
    
    subscript(index: Index) -> Iterator.Element {
        return json[index]
    }
    
    func index(after i: Index) -> Index {
        return json.index(after: i)
    }
    
}

extension JSONDictionary: Equatable {
    
    static func == (lhs: JSONDictionary, rhs: JSONDictionary) -> Bool {
        guard #available(iOS 11.0, *) else {
            // The JSON comparison is not reliable before iOS 11, because the keys order is not deterministic. Since the equality is only tested during unit tests, it's not such a problem.
            return false
        }
        
        let l = try? JSONSerialization.data(withJSONObject: lhs.json, options: [.sortedKeys])
        let r = try? JSONSerialization.data(withJSONObject: rhs.json, options: [.sortedKeys])
        return l == r
    }

}


// MARK: - JSON Parsing

/// enum Example: String {
///     case hello
/// }
/// let json = ["key": "hello"]
/// let value: Example? = parseRaw(json["key"])
func parseRaw<T: RawRepresentable>(_ json: Any?) -> T? {
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
func parseArray<T>(_ json: Any?, allowingSingle: Bool = false) -> [T] {
    if let values = json as? [T] {
        return values
    } else if allowingSingle, let value = json as? T {
        return [value]
    } else {
        return []
    }
}

/// Casting to Double loses precision and fails with integers, eg. json["key"] as? Double.
func parseDouble(_ json: Any?) -> Double? {
    return (json as? NSNumber)?.doubleValue
}

/// Parses a numeric value, but returns nil if it is not a positive number.
func parsePositive<T: Comparable & Numeric>(_ json: Any?) -> T? {
    guard let number = json as? T, number >= 0 else {
        return nil
    }
    return number
}

func parsePositiveDouble(_ json: Any?) -> Double? {
    guard let double = parseDouble(json), double >= 0 else {
        return nil
    }
    return double
}

func parseDate(_ json: Any?) -> Date? {
    return (json as? String)?.dateFromISO8601
}


/// Returns the given JSON object after removing any key with NSNull value.
/// To be used with `encodeIfX` functions for more compact serialization code.
func makeJSON(_ object: [String: Any], additional: [String: Any] = [:]) -> [String: Any] {
    return object.filter { _, value in
        !(value is NSNull)
    }.merging(additional, uniquingKeysWith: { current, _ in current })
}

/// Returns the value if not nil, or NSNull.
func encodeIfNotNil(_ value: Any?) -> Any {
    return value ?? NSNull()
}

/// Returns the raw representable's raw value if not nil, or NSNull. To be used with optional Enum.
func encodeRawIfNotNil<T: RawRepresentable>(_ value: T?) -> Any {
    return value?.rawValue ?? NSNull()
}

/// Returns the collection if not empty, or NSNull.
func encodeIfNotEmpty<T: Collection>(_ collection: T?) -> Any {
    guard let collection = collection else {
        return NSNull()
    }
    return collection.isEmpty ? NSNull() : collection
}
