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

/// Encryption Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/encryption/properties.schema.json
extension Properties {
    
    /// Indicates that a resource is encrypted/obfuscated and provides relevant information for
    /// decryption.
    public var encryption: Encryption? {
        do {
            return try Encryption(json: otherProperties["encrypted"])
        } catch {
            log(.warning, error)
            return nil
        }
    }
    
}
