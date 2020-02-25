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
private let mediaOverlayKey = "media-overlay"
private let overflowKey = "overflow"
private let spreadKey = "spread"
private let encryptedKey = "encrypted"

/// EPUB Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/properties.schema.json
extension Properties {

    /// Identifies content contained in the linked resource, that cannot be strictly identified
    /// using a media type.
    public var contains: [String] {
        get { return parseArray(otherProperties[containsKey]) }
        set { setProperty(newValue, forKey: containsKey) }
    }
    
    /// Hint about the nature of the layout for the linked resources.
    public var layout: EPUBLayout? {
        get { return parseRaw(otherProperties[layoutKey]) }
        set { setProperty(newValue, forKey: layoutKey) }
    }
    
    /// Location of a media-overlay for the resource referenced in the Link Object.
    public var mediaOverlay: String? {
        get { return otherProperties[mediaOverlayKey] as? String }
        set {
            if let mediaOverlay = newValue {
                otherProperties[mediaOverlayKey] = mediaOverlay
            } else {
                otherProperties.removeValue(forKey: mediaOverlayKey)
            }
        }
    }

}
