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
    
    /// Hints how the layout of the resource should be presented.
    public var layout: EPUBRendition.Layout? {
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
    
    /// Suggested method for handling overflow while displaying the linked resource.
    public var overflow: EPUBRendition.Overflow? {
        get { return parseRaw(otherProperties[overflowKey]) }
        set { setProperty(newValue, forKey: overflowKey) }
    }
    
    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic
    /// spread.
    public var spread: EPUBRendition.Spread? {
        get { return parseRaw(otherProperties[spreadKey]) }
        set { setProperty(newValue, forKey: spreadKey) }
    }
    
    /// Indicates that a resource is encrypted/obfuscated and provides relevant information for
    /// decryption.
    public var encryption: EPUBEncryption? {
        get {
            do {
                return try EPUBEncryption(json: otherProperties[encryptedKey])
            } catch {
                log(.warning, error)
                return nil
            }
        }
        set { setProperty(newValue?.json, forKey: encryptedKey) }
    }

}
