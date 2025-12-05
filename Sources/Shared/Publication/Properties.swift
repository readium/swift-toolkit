//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Link Properties
/// https://readium.org/webpub-manifest/schema/properties.schema.json
public struct Properties: Hashable, Loggable, WarningLogger, Sendable {
    /// Additional properties for extensions.
    public var otherProperties: JSONDictionary.Wrapped {
        get { otherPropertiesJSON.json }
        set { otherPropertiesJSON = JSONDictionary(newValue) ?? JSONDictionary() }
    }

    // Trick to keep the struct equatable despite JSONDictionary.Wrapped
    private var otherPropertiesJSON: JSONDictionary

    public init(_ otherProperties: JSONDictionary.Wrapped = [:]) {
        otherPropertiesJSON = JSONDictionary(otherProperties) ?? JSONDictionary()
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        if json == nil {
            return nil
        }
        guard let jsonDictionary = JSONDictionary(json) else {
            warnings?.log("Invalid Properties object", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }
        otherPropertiesJSON = jsonDictionary
    }

    public var json: JSONDictionary.Wrapped {
        makeJSON(otherProperties as [String: Any])
    }

    /// Syntactic sugar to access the `otherProperties` values by subscripting `Properties` directly.
    /// properties["price"] == properties.otherProperties["price"]
    public subscript(key: String) -> Any? {
        otherProperties[key]
    }

    /// Merges in the given additional other `properties`.
    public mutating func add(_ properties: JSONDictionary.Wrapped) {
        otherPropertiesJSON.json.merge(properties, uniquingKeysWith: { _, second in second })
    }
}

/// Core properties
///
/// https://github.com/readium/webpub-manifest/blob/master/properties.md#core-properties
public extension Properties {
    /// Indicates how the linked resource should be displayed in a reading
    /// environment that displays synthetic spreads.
    var page: Page? {
        parseRaw(otherProperties["page"])
    }

    /// Indicates how the linked resource should be displayed in a reading
    /// environment that displays synthetic spreads.
    enum Page: String {
        case left, right, center
    }
}
