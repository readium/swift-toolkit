//
//  EPUBProperties.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// EPUB Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/properties.schema.json
protocol EPUBProperties {

    /// Identifies content contained in the linked resource, that cannot be strictly identified using a media type.
    var contains: [String] { get set }
    
    /// Hints how the layout of the resource should be presented.
    var layout: EPUBRendition.Layout? { get set }
    
    /// Location of a media-overlay for the resource referenced in the Link Object.
    var mediaOverlay: String? { get set }
    
    /// Suggested method for handling overflow while displaying the linked resource.
    var overflow: EPUBRendition.Overflow? { get set }
    
    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic spread.
    var spread: EPUBRendition.Spread? { get set }
    
    /// Indicates that a resource is encrypted/obfuscated and provides relevant information for decryption.
    var encryption: EPUBEncryption? { get set }
    
}


private let containsKey = "contains"
private let layoutKey = "layout"
private let mediaOverlayKey = "media-overlay"
private let overflowKey = "overflow"
private let spreadKey = "spread"
private let encryptedKey = "encrypted"

extension Properties: EPUBProperties {

    public var contains: [String] {
        get { return parseArray(otherProperties[containsKey]) }
        set { setProperty(newValue, forKey: containsKey) }
    }
    
    public var layout: EPUBRendition.Layout? {
        get { return parseRaw(otherProperties[layoutKey]) }
        set { setProperty(newValue, forKey: layoutKey) }
    }
    
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
    
    public var overflow: EPUBRendition.Overflow? {
        get { return parseRaw(otherProperties[overflowKey]) }
        set { setProperty(newValue, forKey: overflowKey) }
    }
    
    public var spread: EPUBRendition.Spread? {
        get { return parseRaw(otherProperties[spreadKey]) }
        set { setProperty(newValue, forKey: spreadKey) }
    }
    
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
