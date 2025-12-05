//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct Encryption {
    /// Identifies the Encryption Profile used by this LCP-protected Publication.
    public let profile: String
    /// Used to encrypt the Publication Resources.
    public let contentKey: ContentKey
    /// Used to encrypt the Content Key.
    public let userKey: UserKey

    init(json: [String: Any]) throws {
        guard let profile = json["profile"] as? String,
              let contentKey = json["content_key"] as? [String: Any],
              let userKey = json["user_key"] as? [String: Any]
        else {
            throw ParsingError.encryption
        }

        self.profile = profile
        self.contentKey = try ContentKey(json: contentKey)
        self.userKey = try UserKey(json: userKey)
    }
}
