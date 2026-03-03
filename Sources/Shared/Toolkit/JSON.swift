//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum JSONError: Error {
    case parsing(Any.Type)
    case serializing(Any.Type)
}

// MARK: - JSON Serialization

public func serializeJSONString(_ object: Any) -> String? {
    guard
        let data = try? JSONSerialization.data(withJSONObject: object, options: .sortedKeys),
        let string = String(data: data, encoding: .utf8)
    else {
        return nil
    }

    // Unescapes slashes
    return string.replacingOccurrences(of: "\\/", with: "/")
}

public func serializeJSONData(_ object: Any) -> Data? {
    guard let string = serializeJSONString(object) else {
        return nil
    }
    return string.data(using: .utf8)
}

// MARK: - JSON Equatable

/// Protocol to automatically conforms to Equatable by comparing the JSON representation of a type.
public protocol JSONEquatable: Equatable, CustomDebugStringConvertible {
    associatedtype JSONType

    var json: JSONType { get }
}

public extension JSONEquatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        let ljson = lhs.json
        let rjson = rhs.json
        guard
            JSONSerialization.isValidJSONObject(ljson),
            JSONSerialization.isValidJSONObject(rjson)
        else {
            return false
        }

        let l = try? JSONSerialization.data(withJSONObject: ljson, options: [.sortedKeys])
        let r = try? JSONSerialization.data(withJSONObject: rjson, options: [.sortedKeys])
        return l == r
    }

    var debugDescription: String {
        serializeJSONString(json) ?? String(describing: self)
    }
}

// MARK: - ReadResult Extensions

public extension Result where Success == Data, Failure == ReadError {
    /// Decodes the data as a JSON value.
    @_spi(Internal) func asJSONValue(options: JSONSerialization.ReadingOptions = []) -> ReadResult<JSONValue> {
        flatMap { data in
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: options)
                guard let value = JSONValue(json) else {
                    return .failure(.decoding(JSONError.parsing(JSONValue.self)))
                }
                return .success(value)
            } catch {
                return .failure(.decoding(error))
            }
        }
    }

    /// Decodes the data as a JSON object.
    @_spi(Internal) func asJSONObjectValue(options: JSONSerialization.ReadingOptions = []) -> ReadResult<[String: JSONValue]> {
        asJSONValue(options: options).flatMap {
            guard let dict = $0.object else {
                return .failure(.decoding(JSONError.parsing([String: JSONValue].self)))
            }
            return .success(dict)
        }
    }
}

public extension Result where Success == Data?, Failure == ReadError {
    /// Decodes the data as a JSON value.
    @_spi(Internal) func asJSONValue(options: JSONSerialization.ReadingOptions = []) -> ReadResult<JSONValue?> {
        flatMap { data in
            guard let data = data else {
                return .success(nil)
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: options)
                guard let value = JSONValue(json) else {
                    return .failure(.decoding(JSONError.parsing(JSONValue.self)))
                }
                return .success(value)
            } catch {
                return .failure(.decoding(error))
            }
        }
    }

    /// Decodes the data as a JSON object.
    @_spi(Internal) func asJSONObjectValue(options: JSONSerialization.ReadingOptions = []) -> ReadResult<[String: JSONValue]?> {
        asJSONValue(options: options).map { $0?.object }
    }
}
