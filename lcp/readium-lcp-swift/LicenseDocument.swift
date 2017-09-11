//
//  LicenseDocument.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

public class LCPLink { // to become Link alone when the repo is created.

}


/// Document that contains references to the various keys, links to related
/// external resources, rights and restrictions that are applied to the
/// Protected Publication, and user information.
public class LicenseDocument {
    /// (encrypted using the User Key) Used to encrypt the Publication Resources.
    public struct ContentKey {
        var encryptedValue: String
        var algorithm: URL

        init(with json: JSON) throws {
            guard let encryptedValue = json["encrypted_value"].string,
                let algorithm = json["algorithm"].url else {
                    throw LcpError.json
            }
            self.encryptedValue = encryptedValue
            self.algorithm = algorithm
        }
    }

    /// Used to encrypt the ContentKey.
    public struct UserKey {
        var hint: String
        var algorithm: URL
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

    public class Encryption {
        /// Identifies the Encryption Profile used by this LCP-protected Publication.
        var profile: URL
        var contentKey: ContentKey
        var userKey: UserKey

        init(with json: JSON) throws {
            guard let profile = json["profile"].url else {
                throw LcpError.json
            }
            self.profile = profile
            try contentKey = ContentKey.init(with: json["content_key"])
            try userKey = UserKey.init(with: json["user_key"])
        }
    }

    var id: String
    /// Date when the license was first issued.
    var issued: Date
    /// Unique identifier for the Provider (URI).
    var provider: URL
    // Encryption object.
    var encryption: Encryption
    /// Used to associate the License Document with resources that are not 
    /// locally available.
    var links = [LCPLink]()
    ///

    /// Date when the license was last updated.
    var updated: Date?

    init(with data: Data) {

    }
}

