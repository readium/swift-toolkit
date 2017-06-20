//
//  Properties.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

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
}

extension Properties: Mappable {

    public init?(map: Map) {}

    /// Return a Boolean indicating wether the property contains informations or
    /// not.
    ///
    /// - Returns: True if empty.
    public func isEmpty() -> Bool {
        guard !contains.isEmpty || layout != nil || mediaOverlay != nil
            || orientation != nil || overflow != nil || page != nil
            || spread != nil || encryption != nil else
        {
            return true
        }
        return false
    }

    /// JSON Mappin utility function.
    public mutating func mapping(map: Map) {
        if !contains.isEmpty {
            contains <- map["contains", ignoreNil: true]
        }
        mediaOverlay <- map["mediaOverlay", ignoreNil: true]
        encryption <- map["encryption", ignoreNil: true]
        layout <- map["layout", ignoreNil: true]
        orientation <- map["orientation", ignoreNil: true]
        overflow <- map["overflow", ignoreNil: true]
        page <- map["page", ignoreNil: true]
        spread <- map["spread", ignoreNil: true]
    }    
}
