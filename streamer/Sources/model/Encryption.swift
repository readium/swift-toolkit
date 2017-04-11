//
//  Encryption.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// Contains metadata parsed from Encryption.xml.
public struct Encryption {
    public var scheme: String?
    public var profile: String?
    public var algorithm: String?
    public var compression: String?
    public var originalLength: Int?

    init() {}

}

extension Encryption: Mappable {
    public init?(map: Map) {}

    public mutating func mapping(map: Map) {
        scheme <- map["scheme", ignoreNil: true]
        profile <- map["profile", ignoreNil: true]
        algorithm <- map["algorithm", ignoreNil: true]
        compression <- map["compression", ignoreNil: true]
        originalLength <- map["originalLength", ignoreNil: true]
    }
}
