//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Link Properties
/// https://readium.org/webpub-manifest/schema/properties.schema.json
public struct Properties: Hashable, Loggable, WarningLogger {
    /// Additional properties for extensions.
    public var otherProperties: [String: Any] {
        get { otherPropertiesJSON.json }
        set { otherPropertiesJSON = JSONDictionary(newValue) ?? JSONDictionary() }
    }

    // Trick to keep the struct equatable despite [String: Any]
    private var otherPropertiesJSON: JSONDictionary

    public init(_ otherProperties: [String: Any] = [:]) {
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

    public var json: [String: Any] {
        makeJSON(otherProperties)
    }

    /// Syntactic sugar to access the `otherProperties` values by subscripting `Properties` directly.
    /// properties["price"] == properties.otherProperties["price"]
    public subscript(key: String) -> Any? {
        otherProperties[key]
    }

    /// Merges in the given additional other `properties`.
    public mutating func add(_ properties: [String: Any]) {
        otherPropertiesJSON.json.merge(properties, uniquingKeysWith: { _, second in second })
    }

    /// Makes a copy of this `Properties` after merging in the given additional other `properties`.
    @available(*, deprecated, message: "Use `add` on a mutable copy")
    public func adding(_ properties: [String: Any]) -> Properties {
        var copy = self
        copy.add(properties)
        return copy
    }
}
