//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Properties associated to a resource.
public struct ResourceProperties {
    public var properties: [String: Any]

    public init(_ properties: [String: Any] = [:]) {
        self.properties = properties
    }

    public init(_ builder: (inout ResourceProperties) -> Void) {
        self.init()
        builder(&self)
    }

    public subscript<T>(_ key: String) -> T? {
        get { properties[key] as? T }
        set {
            if let newValue = newValue {
                properties[key] = newValue
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
        get { properties[filenameKey] as? String }
        set {
            if let filename = newValue {
                properties[filenameKey] = filename
            } else {
                properties.removeValue(forKey: filenameKey)
            }
        }
    }

    /// Known media type for this resource.
    var mediaType: MediaType? {
        get {
            (properties[mediaTypeKey] as? String)
                .flatMap { MediaType($0) }
        }
        set {
            if let mediaType = newValue {
                properties[mediaTypeKey] = mediaType
            } else {
                properties.removeValue(forKey: mediaTypeKey)
            }
        }
    }
}
