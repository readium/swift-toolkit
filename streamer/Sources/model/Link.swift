//
//  Link.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// <#Description#>
open class Link: Mappable {

    public var href: String?
    public var typeLink: String?
    public var rel: [String] = [String]()
    public var height: Int?
    public var width: Int?
    public var title: String?
    public var properties: [String] = [String]()
    public var duration: TimeInterval?
    public var templated: Bool?
    public var children = [Link]()

    // MARK: - Public methods

    public init() {}

    public required init?(map: Map) {
        // TODO: init
    }

    // MARK: - Open methods

    open func mapping(map: Map) {
        href <- map["href"]
        typeLink <- map["type"]
        rel <- map["rel"]
        height <- map["height"]
        width <- map["width"]
        duration <- map["duration"]
        title <- map["title"]
        properties <- map["properties"]
    }
}
