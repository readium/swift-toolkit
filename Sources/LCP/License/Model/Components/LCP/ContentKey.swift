//
//  ContentKey.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Used to encrypt the Publication Resources.
/// This is encrypted using the User Key.
public struct ContentKey {
    
    /// Algorithm used to encrypt the Content Key, identified using the URIs defined in [XML-ENC]. This MUST match the Content Key encryption algorithm named in the Encryption Profile identified in `encryption/profile`.
    public let algorithm: String
    /// Encrypted Content Key.
    public let encryptedValue: String

    init(json: [String: Any]) throws {
        guard let algorithm = json["algorithm"] as? String,
            let encryptedValue = json["encrypted_value"] as? String else
        {
            throw ParsingError.encryption
        }
        
        self.encryptedValue = encryptedValue
        self.algorithm = algorithm
    }
    
}
