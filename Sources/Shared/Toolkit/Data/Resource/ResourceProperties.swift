//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Properties associated to a resource.
public struct ResourceProperties: Hashable {
    public var properties: [String: JSONValue]

    public init(_ properties: [String: JSONValue] = [:]) {
        self.properties = properties
    }

    public init(_ builder: (inout ResourceProperties) -> Void) {
        self.init()
        builder(&self)
    }

    public subscript<T: JSONValueEncodable & JSONValueDecodable>(_ key: String) -> T? {
        get { try? properties[key]?.decode() }
        set {
            if let newValue = newValue {
                properties[key] = newValue.jsonValue
            } else {
                properties.removeValue(forKey: key)
            }
        }
    }
}

private let filenameKey = "https://readium.org/webpub-manifest/properties#filename"
private let mediaTypeKey = "https://readium.org/webpub-manifest/properties#mediaType"

public extension ResourceProperties {
    /// Known filename for this resource.
    var filename: String? {
        get { self[filenameKey] }
        set { self[filenameKey] = newValue }
    }

    /// Known media type for this resource.
    var mediaType: MediaType? {
        get { self[mediaTypeKey] }
        set { self[mediaTypeKey] = newValue }
    }
}
