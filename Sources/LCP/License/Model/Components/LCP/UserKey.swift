//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Used to encrypt the ContentKey.
public struct UserKey: JSONValueDecodable {
    /// A hint to be displayed to the User to help them remember the User Passphrase.
    public let textHint: String
    /// Algorithm used to generate the User Key from the User Passphrase, identified using the URIs defined in [XML-ENC]. This MUST match the User Key hash algorithm named in the Encryption Profile identified in `encryption/profile`.
    public let algorithm: String
    /// The value of the License Document’s `id` field, encrypted using the User Key and the same algorithm identified for Content Key encryption in `encryption/content_key/algorithm`. This is used to verify that the Reading System has the correct User Key.
    public let keyCheck: String

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue.object,
              let textHint = json["text_hint"]?.string,
              let algorithm = json["algorithm"]?.string,
              let keyCheck = json["key_check"]?.string
        else {
            throw ParsingError.encryption
        }

        self.textHint = textHint
        self.algorithm = algorithm
        self.keyCheck = keyCheck
    }
}
