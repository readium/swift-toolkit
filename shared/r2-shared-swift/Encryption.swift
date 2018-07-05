//
//  Encryption.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 4/11/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import ObjectMapper

/// Contains metadata parsed from Encryption.xml.
public struct Encryption {
    /// Identifies the algorithm used to encrypt the resource.
    public var algorithm: String?
    /// Compression method used on the resource.
    public var compression: String?
    /// Original length of the resource in bytes before compression and/or encryption.
    public var originalLength: Int?
    /// Identifies the encryption profile used to encrypt the resource.
    public var profile: String?
    /// Identifies the encryption scheme used to encrypt the resource.
    public var scheme: String?

    public init() {}
}

extension Encryption: Mappable {
    public init?(map: Map) {}

    public mutating func mapping(map: Map) {
        algorithm <- map["algorithm", ignoreNil: true]
        compression <- map["compression", ignoreNil: true]
        originalLength <- map["originalLength", ignoreNil: true]
        profile <- map["profile", ignoreNil: true]
        scheme <- map["scheme", ignoreNil: true]
    }
}
