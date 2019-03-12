//
//  Properties.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Link Properties
/// https://readium.org/webpub-manifest/schema/properties.schema.json
public struct Properties: Equatable {

    /// Suggested orientation for the device when displaying the linked resource.
    public var orientation: RenditionOrientation?

    /// Indicates how the linked resource should be displayed in a reading environment that displays synthetic spreads.
    public var page: RenditionPage?
    

    // MARK: - EPUB Extension
    // https://readium.org/webpub-manifest/schema/extensions/epub/properties.schema.json

    /// Identifies content contained in the linked resource, that cannot be strictly identified using a media type.
    public var contains: [String]
    
    /// Hints how the layout of the resource should be presented.
    public var layout: RenditionLayout?

    /// Location of a media-overlay for the resource referenced in the Link Object.
    public var mediaOverlay: String?
    
    /// Suggested method for handling overflow while displaying the linked resource.
    public var overflow: RenditionOverflow?
    
    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic spread.
    public var spread: RenditionSpread?
    
    /// Indicates that a resource is encrypted/obfuscated and provides relevant information for decryption.
    public var encryption: Encryption?  // RWPM `encrypted`

    
    // MARK: - OPDS Extension
    // https://drafts.opds.io/schema/properties.schema.json
    
    /// Provides a hint about the expected number of items returned.
    public var numberOfItems: Int?
    
    /// The price of a publication is tied to its acquisition link.
    public var price: OPDSPrice?
    
    /// Indirect acquisition provides a hint for the expected media type that will be acquired after additional steps.
    public var indirectAcquisition: [OPDSAcquisition]
    

    /// Additional properties for extensions.
    public var otherProperties: [String: Any] {
        return otherPropertiesJSON.json
    }
    // Trick to keep the struct equatable despite [String: Any]
    private var otherPropertiesJSON: JSONDictionary

    
    public init(orientation: RenditionOrientation? = nil, page: RenditionPage? = nil, contains: [String] = [], layout: RenditionLayout? = nil, mediaOverlay: String? = nil, overflow: RenditionOverflow? = nil, spread: RenditionSpread? = nil, encryption: Encryption? = nil, numberOfItems: Int? = nil, price: OPDSPrice? = nil, indirectAcquisition: [OPDSAcquisition] = [], otherProperties: [String: Any] = [:]) {
        self.orientation = orientation
        self.page = page
        self.contains = contains
        self.layout = layout
        self.mediaOverlay = mediaOverlay
        self.overflow = overflow
        self.spread = spread
        self.encryption = encryption
        self.numberOfItems = numberOfItems
        self.price = price
        self.indirectAcquisition = indirectAcquisition
        self.otherPropertiesJSON = JSONDictionary(otherProperties) ?? JSONDictionary()
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard var json = JSONDictionary(json) else {
            throw JSONParsingError.properties
        }
        
        self.orientation = parseRaw(json.pop("orientation"))
        self.page = parseRaw(json.pop("page"))
        self.contains = parseArray(json.pop("contains"))
        self.layout = parseRaw(json.pop("layout"))
        self.mediaOverlay = json.pop("media-overlay") as? String
        self.overflow = parseRaw(json.pop("overflow"))
        self.spread = parseRaw(json.pop("spread"))
        self.encryption = try Encryption(json: json.pop("encrypted"))
        self.numberOfItems = parsePositive(json.pop("numberOfItems"))
        self.price = try OPDSPrice(json: json.pop("price"))
        self.indirectAcquisition = [OPDSAcquisition](json: json.pop("indirectAcquisition"))
        self.otherPropertiesJSON = json
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "orientation": encodeRawIfNotNil(orientation),
            "page": encodeRawIfNotNil(page),
            "contains": encodeIfNotEmpty(contains),
            "layout": encodeRawIfNotNil(layout),
            "media-overlay": encodeIfNotNil(mediaOverlay),
            "overflow": encodeRawIfNotNil(overflow),
            "spread": encodeRawIfNotNil(spread),
            "encrypted": encodeIfNotNil(encryption?.json),
            "numberOfItems": encodeIfNotNil(numberOfItems),
            "price": encodeIfNotNil(price?.json),
            "indirectAcquisition": encodeIfNotEmpty(indirectAcquisition.json),
        ], additional: otherProperties)
    }

}
