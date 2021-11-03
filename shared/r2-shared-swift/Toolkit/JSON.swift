//
//  JSON.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


// MARK: - JSON Serialization

public func serializeJSONString(_ object: Any) -> String? {
    var options: JSONSerialization.WritingOptions = []
    if #available(iOS 11.0, *) {
        options.insert(.sortedKeys)
    }
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: options),
        let string = String(data: data, encoding: .utf8) else
    {
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
/// WARNING: this is only reliable on iOS 11+, because the keys order is not deterministic before. So only use JSON equality comparisons in unit tests, for example.
public protocol JSONEquatable: Equatable, CustomDebugStringConvertible {
    associatedtype JSONType
    
    var json: JSONType { get }
    
}

extension JSONEquatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        let ljson = lhs.json
        let rjson = rhs.json
        guard #available(iOS 11.0, *),
            JSONSerialization.isValidJSONObject(ljson),
            JSONSerialization.isValidJSONObject(rjson) else
        {
            return false
        }
        
        let l = try? JSONSerialization.data(withJSONObject: ljson, options: [.sortedKeys])
        let r = try? JSONSerialization.data(withJSONObject: rjson, options: [.sortedKeys])
        return l == r
    }
    
    public var debugDescription: String {
        serializeJSONString(json) ?? String(describing: self)
    }
    
}
