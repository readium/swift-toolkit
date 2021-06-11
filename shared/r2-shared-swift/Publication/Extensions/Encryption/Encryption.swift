//
//  Encryption.swift
//  r2-shared-swift
//
//  Created by Mickaël on 25/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Indicates that a resource is encrypted/obfuscated and provides relevant information for
/// decryption.
public struct Encryption: Equatable {
    
    /// Identifies the algorithm used to encrypt the resource.
    public let algorithm: String  // URI
    
    /// Compression method used on the resource.
    public let compression: String?
    
    /// Original length of the resource in bytes before compression and/or encryption.
    public let originalLength: Int?
    
    /// Identifies the encryption profile used to encrypt the resource.
    public let profile: String?  // URI
    
    /// Identifies the encryption scheme used to encrypt the resource.
    public let scheme: String?  // URI
    
    
    public init(algorithm: String, compression: String? = nil, originalLength: Int? = nil, profile: String? = nil, scheme: String? = nil) {
        self.algorithm = algorithm
        self.compression = compression
        self.originalLength = originalLength
        self.profile = profile
        self.scheme = scheme
    }
    
    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        // Convenience when parsing parent structures.
        if json == nil {
            return nil
        }
        guard let jsonObject = json as? [String: Any],
            let algorithm = jsonObject["algorithm"] as? String else
        {
            warnings?.log("`algorithm` is required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }
        
        self.init(
            algorithm: algorithm,
            compression: jsonObject["compression"] as? String,
            originalLength: jsonObject["originalLength"] as? Int
                // Fallback on `original-length` for legacy reasons
                // See https://github.com/readium/webpub-manifest/pull/43
                ?? jsonObject["original-length"] as? Int,
            profile: jsonObject["profile"] as? String,
            scheme: jsonObject["scheme"] as? String
        )
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "algorithm": algorithm,
            "compression": encodeIfNotNil(compression),
            "originalLength": encodeIfNotNil(originalLength),
            "profile": encodeIfNotNil(profile),
            "scheme": encodeIfNotNil(scheme)
        ])
    }
    
}
