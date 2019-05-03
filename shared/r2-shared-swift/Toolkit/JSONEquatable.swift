//
//  JSONEquatable.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Protocol to automatically conforms to Equatable by comparing the JSON representation of a type.
/// WARNING: this is only reliable on iOS 11+, because the keys order is not deterministic before. So only use JSON equality comparisons in unit tests, for example.
public protocol JSONEquatable: Equatable {
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
    
}


