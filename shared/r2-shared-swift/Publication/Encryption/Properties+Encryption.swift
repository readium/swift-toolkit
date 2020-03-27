//
//  Properties+Encryption.swift
//  r2-shared-swift
//
//  Created by Mickaël on 25/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

private let encryptedKey = "encrypted"

/// Encryption Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/encryption/properties.schema.json
extension Properties {
    
    /// Indicates that a resource is encrypted/obfuscated and provides relevant information for
    /// decryption.
    public var encryption: Encryption? {
        get {
            do {
                return try Encryption(json: otherProperties[encryptedKey])
            } catch {
                log(.warning, error)
                return nil
            }
        }
        set { setProperty(newValue?.json, forKey: encryptedKey) }
    }
    
}
