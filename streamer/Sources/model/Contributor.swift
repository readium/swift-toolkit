//
//  Contributors.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

// TODO: desentrelace model with JSON mapper library
/// <#Description#>
open class Contributor: Mappable {
    
    public var name: String
    public var sortAs: String?
    public var identifier: String?
    public var role: String?

    public init(name: String) {
        self.name = name
    }

    public required init?(map: Map) {
        guard map.JSON["name"] != nil else {
            return nil
        }

        name = try! map.value("name")
        sortAs = try? map.value("sortAs")
        identifier = try? map.value("identifier")
        role = try? map.value("role")
    }

    open func mapping(map: Map) {
        name <- map["name"]
        sortAs <- map["sortAs"]
        identifier <- map["identifier"]
        role <- map["role"]
    }
}
