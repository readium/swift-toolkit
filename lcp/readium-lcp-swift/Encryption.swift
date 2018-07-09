//
//  Encryption.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SwiftyJSON

public struct Encryption {
    /// Identifies the Encryption Profile used by this LCP-protected Publication.
    var profile: URL
    /// Used to encrypt the Publication Resources.
    var contentKey: ContentKey
    /// Used to encrypt the Content Key.
    var userKey: UserKey

    init(with json: JSON) throws {
        guard let profile = json["profile"].url else {
            throw LcpParsingError.encryption
        }
        self.profile = profile
        try contentKey = ContentKey.init(with: json["content_key"])
        try userKey = UserKey.init(with: json["user_key"])
    }
}
