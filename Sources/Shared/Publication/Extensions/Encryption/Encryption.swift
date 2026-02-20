//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Indicates that a resource is encrypted/obfuscated and provides relevant information for
/// decryption.
public struct Encryption: Equatable, Sendable {
    /// Identifies the algorithm used to encrypt the resource.
    public let algorithm: String // URI

    /// Compression method used on the resource.
    public let compression: String?

    /// Original length of the resource in bytes before compression and/or encryption.
    public let originalLength: Int?

    /// Identifies the encryption profile used to encrypt the resource.
    public let profile: String? // URI

    /// Identifies the encryption scheme used to encrypt the resource.
    public let scheme: String? // URI

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
        guard let jsonDict = JSONDictionary(json),
              let algorithm = jsonDict.json["algorithm"]?.string
        else {
            warnings?.log("`algorithm` is required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }
        let jsonObject = jsonDict.json

        self.init(
            algorithm: algorithm,
            compression: jsonObject["compression"]?.string,
            originalLength: jsonObject["originalLength"]?.integer
                // Fallback on `original-length` for legacy reasons
                // See https://github.com/readium/webpub-manifest/pull/43
                ?? jsonObject["original-length"]?.integer,
            profile: jsonObject["profile"]?.string,
            scheme: jsonObject["scheme"]?.string
        )
    }

    public var json: [String: JSONValue] {
        makeJSON([
            "algorithm": .string(algorithm),
            "compression": encodeIfNotNil(compression),
            "originalLength": encodeIfNotNil(originalLength),
            "profile": encodeIfNotNil(profile),
            "scheme": encodeIfNotNil(scheme),
        ])
    }
}
