//
//  UserKey.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

/// Used to encrypt the ContentKey.
public struct UserKey {
    /// A hint to be displayed to the User to help them remember the User
    /// Passphrase.
    var hint: String
    /// Algorithm used to generate the User Key from the User Passphrase, 
    /// identified using the URIs defined in [XML-ENC]. This MUST match the User
    /// Key hash algorithm named in the Encryption Profile identified in 
    /// `encryption/profile`.
    var algorithm: URL
    /// The value of the License Document’s `id` field, encrypted using the User
    /// Key and the same algorithm identified for Content Key encryption in 
    /// `encryption/content_key/algorithm`. This is used to verify that the 
    /// Reading System has the correct User Key.
    var keyCheck: String

    init(with json: JSON) throws {
        guard let hint = json["text_hint"].string,
            let algorithm = json["algorithm"].url,
            let keyCheck = json["key_check"].string else {
                throw LcpError.json
        }
        self.hint = hint
        self.algorithm = algorithm
        self.keyCheck = keyCheck
    }

}
