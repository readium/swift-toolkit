//
//  ContentKey.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

/// (encrypted using the User Key) Used to encrypt the Publication Resources.
public struct ContentKey {
    /// Encrypted Content Key.
    var encryptedValue: String
    /// Algorithm used to encrypt the Content Key, identified using the URIs 
    /// defined in [XML-ENC]. This MUST match the Content Key encryption 
    /// algorithm named in the Encryption Profile identified in 
    /// `encryption/profile`.
    var algorithm: URL

    init(with json: JSON) throws {
        guard let encryptedValue = json["encrypted_value"].string,
            let algorithm = json["algorithm"].url else {
                throw LcpParsingError.json
        }
        self.encryptedValue = encryptedValue
        self.algorithm = algorithm
    }
}
