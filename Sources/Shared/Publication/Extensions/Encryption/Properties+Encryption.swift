//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Encryption Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/encryption/properties.schema.json
public extension Properties {
    /// Indicates that a resource is encrypted/obfuscated and provides relevant information for
    /// decryption.
    var encryption: Encryption? {
        try? Encryption(json: otherProperties["encrypted"], warnings: self)
    }
}
