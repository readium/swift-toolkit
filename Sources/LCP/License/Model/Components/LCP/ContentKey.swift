//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Used to encrypt the Publication Resources.
/// This is encrypted using the User Key.
public struct ContentKey: Sendable {
    /// Algorithm used to encrypt the Content Key, identified using the URIs defined in [XML-ENC]. This MUST match the Content Key encryption algorithm named in the Encryption Profile identified in `encryption/profile`.
    public let algorithm: String
    /// Encrypted Content Key.
    public let encryptedValue: String

    init(json: JSONValue?) throws {
        guard var json = JSONDictionary(json),
              let algorithm = json.pop("algorithm")?.string,
              let encryptedValue = json.pop("encrypted_value")?.string
        else {
            throw ParsingError.encryption
        }

        self.encryptedValue = encryptedValue
        self.algorithm = algorithm
    }

    init(json: [String: Any]) throws {
        try self.init(json: JSONValue(json))
    }
}
