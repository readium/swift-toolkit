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

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue.object,
              let profile = json["profile"]?.string,
              let contentKey = try ContentKey(json: json["content_key"], warnings: warnings),
              let userKey = try UserKey(json: json["user_key"], warnings: warnings)
        else {
            throw ParsingError.encryption
        }

        self.profile = profile
        self.contentKey = contentKey
        self.userKey = userKey
    }
}
