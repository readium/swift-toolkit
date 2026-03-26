//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Link Properties
/// https://readium.org/webpub-manifest/schema/properties.schema.json
public struct Properties: Hashable, Loggable, WarningLogger, Sendable, JSONValueDecodable, JSONObjectEncodable {
    /// Additional properties for extensions.
    public var otherProperties: [String: JSONValue]

    public init(_ otherProperties: [String: JSONValue] = [:]) {
        self.otherProperties = otherProperties
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }
        guard let jsonObject = json.object else {
            warnings?.log("Invalid Properties object", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }
        otherProperties = jsonObject
    }

    public var jsonObject: [String: JSONValue] {
        otherProperties
    }

    /// Syntactic sugar to access the `otherProperties` values by subscripting `Properties` directly.
    /// properties["price"] == properties.otherProperties["price"]
    public subscript(key: String) -> JSONValue? {
        otherProperties[key]
    }

    /// Merges in the given additional other `properties`.
    public mutating func add(_ properties: [String: JSONValue]) {
        otherProperties.merge(properties, uniquingKeysWith: { _, second in second })
    }
}

/// Core properties
///
/// https://github.com/readium/webpub-manifest/blob/master/properties.md#core-properties
public extension Properties {
    private static var pageKey: String {
        "page"
    }

    /// Indicates how the linked resource should be displayed in a reading
    /// environment that displays synthetic spreads.
    var page: Page? {
        get { otherProperties[Self.pageKey]?.decode() }
        set {
            if let newValue = newValue {
                otherProperties[Self.pageKey] = .string(newValue.rawValue)
            } else {
                otherProperties.removeValue(forKey: Self.pageKey)
            }
        }
    }

    /// Indicates how the linked resource should be displayed in a reading
    /// environment that displays synthetic spreads.
    enum Page: String {
        case left, right, center
    }
}
