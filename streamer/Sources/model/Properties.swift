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
/// -- TOVERIF/IMPL [Used also in Rendition for fxl]
public struct Properties {
    public var contains = [String]()
    public var layout: String?
    public var mediaOverlay: String?
    public var orientation: String?
    public var overflow: String?
    public var page: String?
    public var spread: String?
    public var encryption: Encryption?
}
//
//extension Properties: Mappable {
//
//    public init?(map: Map) {}
//
//    public mutating func mapping(map: Map) {
//        if !contains.isEmpty {
//            contains <- map["contains", ignoreNil: true]
//        }
//        layout <- map["layout", ignoreNil: true]
//        if !mediaOverlay.isEmpty {
//            mediaOverlay <- map["mediaOverlay", ignoreNil: true]
//        }
//        orientation <- map["orientation", ignoreNil: true]
//        overflow <- map["overflow", ignoreNil: true]
//        page <- map["page", ignoreNil: true]
//        spread <- map["spread", ignoreNil: true]
//        encryption <- map["encryption", ignoreNil: true]
//    }    
//}
