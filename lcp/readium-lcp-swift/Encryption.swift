//
//  Encryption.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//  Copyright © 2017 Readium. All rights reserved.
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
            throw LcpError.encryption
        }
        self.profile = profile
        try contentKey = ContentKey.init(with: json["content_key"])
        try userKey = UserKey.init(with: json["user_key"])
    }
}
