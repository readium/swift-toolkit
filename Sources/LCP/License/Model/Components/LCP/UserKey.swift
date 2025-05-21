//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Used to encrypt the ContentKey.
public struct UserKey {
    /// A hint to be displayed to the User to help them remember the User Passphrase.
    public let textHint: String
    /// Algorithm used to generate the User Key from the User Passphrase, identified using the URIs defined in [XML-ENC]. This MUST match the User Key hash algorithm named in the Encryption Profile identified in `encryption/profile`.
    public let algorithm: String
    /// The value of the License Document’s `id` field, encrypted using the User Key and the same algorithm identified for Content Key encryption in `encryption/content_key/algorithm`. This is used to verify that the Reading System has the correct User Key.
    public let keyCheck: String

    init(json: [String: Any]) throws {
        guard let textHint = json["text_hint"] as? String,
              let algorithm = json["algorithm"] as? String,
              let keyCheck = json["key_check"] as? String
        else {
            throw ParsingError.encryption
        }

        self.textHint = textHint
        self.algorithm = algorithm
        self.keyCheck = keyCheck
    }
}
