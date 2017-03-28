//
//  Link.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

public class Link: Mappable {

    public var href: String?
    public var typeLink: String?
    public var rel = [String]()
    public var height: Int?
    public var width: Int?
    public var title: String?
    public var properties = [String]()
    public var duration: TimeInterval?
    public var templated: Bool?
    public var children = [Link]()

    // MARK: - Public methods

    public init() {}

    public required init?(map: Map) {
    }

    // MARK: - Open methods

    open func mapping(map: Map) {
        href <- map["href", ignoreNil: true]
        typeLink <- map["type", ignoreNil: true]
        if !rel.isEmpty {
            rel <- map["rel", ignoreNil: true]
        }
        height <- map["height", ignoreNil: true]
        width <- map["width", ignoreNil: true]
        duration <- map["duration", ignoreNil: true]
        title <- map["title", ignoreNil: true]
        if !properties.isEmpty {
            properties <- map["properties", ignoreNil: true]
        }
    }
}
