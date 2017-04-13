//
//  Link.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

public class Link {
    public var href: String?
    public var typeLink: String?
    public var rel: [String]!
    public var height: Int?
    public var width: Int?
    public var title: String?
    //public var properties = [String]()
    public var properties: Properties!
    public var duration: TimeInterval?
    public var templated: Bool?
    public var children: [Link]!
    public var mediaOverlays: MediaOverlays!

    // MARK: - Public methods

    public init() {
        properties = Properties()
        mediaOverlays = MediaOverlays()
        rel = [String]()
        children = [Link]()
    }

    public required init?(map: Map) {}
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
        //properties <- map["properties", ignoreNil: true]
        /// Properties mapping
        if !properties.contains.isEmpty {
            properties.contains <- map["properties.contains", ignoreNil: true]
        }
        properties.layout <- map["properties.layout", ignoreNil: true]
        properties.mediaOverlay <- map["properties.mediaOverlay", ignoreNil: true]
        properties.orientation <- map["properties.orientation", ignoreNil: true]
        properties.overflow <- map["properties.overflow", ignoreNil: true]
        properties.page <- map["properties.page", ignoreNil: true]
        properties.spread <- map["properties.spread", ignoreNil: true]
        properties.encryption <- map["properties.encryption", ignoreNil: true]
        /// Properties mapping end
    }
}

