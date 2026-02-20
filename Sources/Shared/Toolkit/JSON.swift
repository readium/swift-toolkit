//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

public enum JSONError: Error {
    case parsing(Any.Type)
    case serializing(Any.Type)
}

// MARK: - JSON Serialization

public func serializeJSONString(_ object: Any) -> String? {
    var object = object
    if let dict = object as? [String: JSONValue] {
        object = dict.mapValues { $0.any }
    } else if let array = object as? [JSONValue] {
        object = array.map(\.any)
    } else if let val = object as? JSONValue {
        object = val.any
    }

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

        // Fast path for JSONValue types which are Equatable
        if let l = ljson as? JSONValue, let r = rjson as? JSONValue {
            return l == r
        }
        if let l = ljson as? [String: JSONValue], let r = rjson as? [String: JSONValue] {
            return l == r
        }
        if let l = ljson as? [JSONValue], let r = rjson as? [JSONValue] {
            return l == r
        }

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
