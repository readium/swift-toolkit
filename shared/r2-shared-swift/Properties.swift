//
//  Properties.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 4/11/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Properties object used for `Link`s properties.
public struct Properties {
    /// Suggested orientation for the device when displaying the linked resource.
    public var orientation: String?
    /// Indicates how the linked resource should be displayed in a reading
    /// environment that displays synthetic spreads.
    public var page: String?
    /// Indentifies content contained in the linked resource, that cannot be 
    /// strictly identified using a media type.
    public var contains = [String]()
    /// Location of a media-overlay for the resource referenced in the Link Object.
    public var mediaOverlay: String?
    /// Indicates that a resource is encrypted/obfuscated and provides relevant
    /// information for decryption.
    public var encryption: Encryption?
    /// Hint about the nature of the layout for the linked resources.
    public var layout: String?
    /// Suggested method for handling overflow while displaying the linked resource.
    public var overflow: String?
    /// Indicates the condition to be met for the linked resource to be rendered
    /// within a synthetic spread.
    public var spread: String?
    ///
    public var numberOfItems: Int?
    ///
    public var price: Price?
    ///
    public var indirectAcquisition: [IndirectAcquisition]?

    public init() {}
    
    /// Return a Boolean indicating wether the property contains informations or
    /// not.
    ///
    /// - Returns: True if empty.
    public func isEmpty() -> Bool {
        guard !contains.isEmpty
          || layout != nil
          || mediaOverlay != nil
          || orientation != nil
          || overflow != nil
          || page != nil
          || spread != nil
          || encryption != nil else
        {
            return true
        }
        return false
    }
    
}


extension Properties: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case contains
        case encryption
        case layout
        case mediaOverlay
        case orientation
        case overflow
        case page
        case spread
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !contains.isEmpty {
            try container.encode(contains, forKey: .contains)
        }
        try container.encodeIfPresent(encryption, forKey: .encryption)
        try container.encodeIfPresent(layout, forKey: .layout)
        try container.encodeIfPresent(mediaOverlay, forKey: .mediaOverlay)
        try container.encodeIfPresent(orientation, forKey: .orientation)
        try container.encodeIfPresent(overflow, forKey: .overflow)
        try container.encodeIfPresent(page, forKey: .page)
        try container.encodeIfPresent(spread, forKey: .spread)
    }
        
}
