//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

private let containsKey = "contains"
private let layoutKey = "layout"
private let overflowKey = "overflow"
private let spreadKey = "spread"
private let encryptedKey = "encrypted"

/// EPUB Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/properties.schema.json
public extension Properties {
    /// Identifies content contained in the linked resource, that cannot be strictly identified
    /// using a media type.
    var contains: [String] {
        parseArray(otherProperties["contains"])
    }

    /// Hint about the nature of the layout for the linked resources.
    @available(*, unavailable, message: "This was removed from RWPM. You can still use the EPUB extensibility to access the original value.")
    var layout: EPUBLayout? {
        parseRaw(otherProperties["layout"])
    }
}
