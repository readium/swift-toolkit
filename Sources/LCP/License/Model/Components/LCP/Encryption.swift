//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public struct Encryption: JSONValueDecodable {
    /// Identifies the Encryption Profile used by this LCP-protected Publication.
    public let profile: String
    /// Used to encrypt the Publication Resources.
    public let contentKey: ContentKey
    /// Used to encrypt the Content Key.
    public let userKey: UserKey

    public init(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        guard let json = json?.object,
              let profile = json["profile"]?.string,
              let contentKeyJSON = json["content_key"],
              let userKeyJSON = json["user_key"]
        else {
            throw ParsingError.encryption
        }

        self.profile = profile

        contentKey = try ContentKey(json: contentKeyJSON)
        userKey = try UserKey(json: userKeyJSON)
    }
}
