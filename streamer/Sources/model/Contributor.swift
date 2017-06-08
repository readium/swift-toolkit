//
//  Contributors.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

open class Contributor {
    internal var _name = MultilangString()
    public var name: String? {
        get {
            return _name.singleString
        }
    }
    public var sortAs: String?
    public var identifier: String?
    public var role: String?

    public init() {}

    public required init?(map: Map) {
//        _name.singleString = try? map.value("name")
//        sortAs = try? map.value("sortAs")
//        identifier = try? map.value("identifier")
//        role = try? map.value("role")
    }

}

extension Contributor: Mappable {

    open func mapping(map: Map) {
        // If multiString is not empty, then serialize it.
        if !_name.multiString.isEmpty {
            _name.multiString <- map["name"]
        } else {
            var nameForSinglestring = _name.singleString ?? ""

            nameForSinglestring <- map["name"]
        }
        sortAs <- map["sortAs", ignoreNil: true]
        identifier <- map["identifier", ignoreNil: true]
        role <- map["role", ignoreNil: true]
    }
}
