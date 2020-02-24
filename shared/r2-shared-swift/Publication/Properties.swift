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
    
    /// Suggested orientation for the device when displaying the linked resource.
    public enum Orientation: String {
        case auto, landscape, portrait
    }
    
    /// Indicates how the linked resource should be displayed in a reading environment that displays synthetic spreads.
    public enum Page: String {
        case left, right, center
    }

    /// Suggested orientation for the device when displaying the linked resource.
    public var orientation: Orientation?

    /// Indicates how the linked resource should be displayed in a reading environment that displays synthetic spreads.
    public var page: Page?
    
    /// Additional properties for extensions.
    public var otherProperties: [String: Any] {
        get { return otherPropertiesJSON.json }
        set { otherPropertiesJSON.json = newValue }
    }
    // Trick to keep the struct equatable despite [String: Any]
    private var otherPropertiesJSON: JSONDictionary

    
    public init(orientation: Orientation? = nil, page: Page? = nil, otherProperties: [String: Any] = [:]) {
        self.orientation = orientation
        self.page = page
        self.otherPropertiesJSON = JSONDictionary(otherProperties) ?? JSONDictionary()
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard var json = JSONDictionary(json) else {
            throw JSONError.parsing(Properties.self)
        }
        
        self.orientation = parseRaw(json.pop("orientation"))
        self.page = parseRaw(json.pop("page"))
        self.otherPropertiesJSON = json
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "orientation": encodeRawIfNotNil(orientation),
            "page": encodeRawIfNotNil(page),
        ], additional: otherProperties)
    }

    /// Syntactic sugar to access the `otherProperties` values by subscripting `Properties` directly.
    /// properties["price"] == properties.otherProperties["price"]
    public subscript(key: String) -> Any? {
        get { return otherProperties[key] }
        set { otherProperties[key] = newValue }
    }
    
    
    // MARK: Extension tools
    
    mutating func setProperty<T: RawRepresentable>(_ value: T?, forKey key: String) {
        if let value = value {
            otherProperties[key] = value.rawValue
        } else {
            otherProperties.removeValue(forKey: key)
        }
    }
    
    mutating func setProperty<T: Collection>(_ value: T?, forKey key: String) {
        if let value = value, !value.isEmpty {
            otherProperties[key] = value
        } else {
            otherProperties.removeValue(forKey: key)
        }
    }

}
