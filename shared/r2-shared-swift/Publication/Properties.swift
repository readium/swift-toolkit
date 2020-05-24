//
//  Properties.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Link Properties
/// https://readium.org/webpub-manifest/schema/properties.schema.json
public struct Properties: Equatable, Loggable {
    
    /// Additional properties for extensions.
    public var otherProperties: [String: Any] { otherPropertiesJSON.json }
    
    // Trick to keep the struct equatable despite [String: Any]
    private let otherPropertiesJSON: JSONDictionary

    public init(_ otherProperties: [String: Any] = [:]) {
        self.otherPropertiesJSON = JSONDictionary(otherProperties) ?? JSONDictionary()
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard let json = JSONDictionary(json) else {
            throw JSONError.parsing(Properties.self)
        }
        self.otherPropertiesJSON = json
    }
    
    public var json: [String: Any] {
        makeJSON(otherProperties)
    }

    /// Syntactic sugar to access the `otherProperties` values by subscripting `Properties` directly.
    /// properties["price"] == properties.otherProperties["price"]
    public subscript(key: String) -> Any? {
        otherProperties[key]
    }

}
