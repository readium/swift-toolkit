//
//  Subject.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// WebPub manifest spec
/// https://github.com/readium/webpub-manifest/blob/master/contexts/default/definitions.md#subjects
/// Epub 3.1
/// http://www.idpf.org/epub/31/spec/epub-packages.html#sec-opf-dcsubject
public class Subject {
    var name: String?
    /// The WebPubManifest elements
    var sortAs: String?
    /// Epub 3.1 "scheme" (opf:authority)
    var scheme: String?
    /// Epub 3.1 "code" (opf:term)
    var code: String?

    public init() {}
    
    public required init?(map: Map) {}
}

extension Subject: Mappable {
    open func mapping(map: Map) {
        name <- map["name", ignoreNil: true]
        sortAs <- map["sortAs", ignoreNil: true]
        scheme <- map["scheme", ignoreNil: true]
        code <- map["code", ignoreNil: true]
    }
}
