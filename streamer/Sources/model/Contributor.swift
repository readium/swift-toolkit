//
//  Contributors.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

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

        // FIXME: try!
        name = try! map.value("name")
        sortAs = try? map.value("sortAs")
        identifier = try? map.value("identifier")
        role = try? map.value("role")
    }

    open func mapping(map: Map) {
        name <- map["name", ignoreNil: true]
        sortAs <- map["sortAs", ignoreNil: true]
        identifier <- map["identifier", ignoreNil: true]
        role <- map["role", ignoreNil: true]
    }
}
