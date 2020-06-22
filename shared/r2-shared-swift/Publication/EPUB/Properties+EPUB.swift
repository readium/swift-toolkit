//
//  Properties+EPUB.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

private let containsKey = "contains"
private let layoutKey = "layout"
private let overflowKey = "overflow"
private let spreadKey = "spread"
private let encryptedKey = "encrypted"

/// EPUB Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/properties.schema.json
extension Properties {

    /// Identifies content contained in the linked resource, that cannot be strictly identified
    /// using a media type.
    public var contains: [String] {
        parseArray(otherProperties["contains"])
    }
    
    /// Hint about the nature of the layout for the linked resources.
    public var layout: EPUBLayout? {
        parseRaw(otherProperties["layout"])
    }

}
