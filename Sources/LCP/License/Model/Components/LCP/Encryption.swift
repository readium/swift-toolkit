//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public struct Encryption {
    /// Identifies the Encryption Profile used by this LCP-protected Publication.
    public let profile: String
    /// Used to encrypt the Publication Resources.
    public let contentKey: ContentKey
    /// Used to encrypt the Content Key.
    public let userKey: UserKey

    init(json: JSONValue?) throws {
        guard var json = JSONDictionary(json),
              let profile = json.pop("profile")?.string,
              let contentKeyJSON = json.pop("content_key"),
              let userKeyJSON = json.pop("user_key")
        else {
            throw ParsingError.encryption
        }

        self.profile = profile

        contentKey = try ContentKey(json: contentKeyJSON)
        userKey = try UserKey(json: userKeyJSON)
    }

    init(json: [String: Any]) throws {
        try self.init(json: JSONValue(json))
    }
}
