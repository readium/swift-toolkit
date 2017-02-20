//
//  Subject.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

// TODO: desentrelace model with JSON mapper library
/// <#Description#>
open class Subject: Mappable {

    public var name: String?
    public var sortAs: String?
    public var scheme: String?
    public var code: String?

    public init() {}

    required public init?(map: Map) {
        // TODO: init
    }

    open func mapping(map: Map) {
        name <- map["name"]
        sortAs <- map["sortAs"]
        scheme <- map["scheme"]
        code <- map["code"]
    }
}
