//
//  Link.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// A Link to a resource.
public class Link {
    /// The link destination.
    public var href: String?
    /// The link destination (absolute URL).
    public var absoluteHref: String?
    /// MIME type of resource.
    public var typeLink: String?
    /// Indicates the relationship between the resource and its containing collection.
    public var rel = [String]()
    /// Indicates the height of the linked resource in pixels.
    public var height: Int?
    /// Indicates the width of the linked resource in pixels.
    public var width: Int?
    public var title: String?
    /// Properties associated to the linked resource.
    public var properties = Properties()
    /// Indicates the length of the linked resource in seconds.
    public var duration: TimeInterval?
    /// Indicates that the linked resource is a URI template.
    public var templated: Bool?
    /// Indicate the bitrate for the link resource.
    public var bitrate: Int?
    

    /// The underlaying nodes in a tree structure of `Link`s.
    public var children = [Link]()
    /// The MediaOverlays associated to the resource of the `Link`.
    public var mediaOverlays = MediaOverlays()

    public init() {}

    public required init?(map: Map) {}

    /// Check wether a link's resource is encrypted by checking is 
    /// properties.encrypted is set.
    ///
    /// - Returns: True if encrypted.
    public func isEncrypted() -> Bool {
        guard let _ = properties.encryption else {
            return false
        }
        return true
    }
}

extension Link: Mappable {
    public func mapping(map: Map) {
        href <- map["href", ignoreNil: true]
        typeLink <- map["type", ignoreNil: true]
        if !rel.isEmpty {
            rel <- map["rel", ignoreNil: true]
        }
        height <- map["height", ignoreNil: true]
        width <- map["width", ignoreNil: true]
        duration <- map["duration", ignoreNil: true]
        title <- map["title", ignoreNil: true]
        if !properties.isEmpty() {
            properties <- map["properties", ignoreNil: true]
        }
    }
}

