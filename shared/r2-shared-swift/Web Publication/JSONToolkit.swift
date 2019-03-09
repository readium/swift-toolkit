//
//  JSONToolkit.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


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


// MARK: - JSON Serialization

/// Returns the given JSON object after removing any key with NSNull value.
/// To be used with `encodeIfX` functions for more compact serialization code.
func makeJSON(_ object: [String: Any]) -> [String: Any] {
    return object.filter { _, value in
        !(value is NSNull)
    }
}

/// Returns the value if not nil, or NSNull.
func encodeIfNotNil(_ value: Any?) -> Any {
    return value ?? NSNull()
}

/// Returns the raw representable's raw value if not nil, or NSNull. To be used with optional Enum.
func encodeRawIfNotNil<T: RawRepresentable>(_ value: T?) -> Any {
    return value?.rawValue ?? NSNull()
}

/// Returns the array if not empty, or NSNull.
func encodeIfNotEmpty(_ array: [Any]) -> Any {
    return array.isEmpty ? NSNull() : array
}
