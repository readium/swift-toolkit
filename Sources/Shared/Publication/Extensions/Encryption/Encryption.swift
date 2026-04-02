//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Indicates that a resource is encrypted/obfuscated and provides relevant information for
/// decryption.
public struct Encryption: Equatable, JSONValueDecodable, JSONObjectEncodable {
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

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        // Convenience when parsing parent structures.
        guard let json = json?.jsonValue else {
            return nil
        }
        guard let jsonObject = json.object,
              let algorithm = jsonObject["algorithm"]?.string
        else {
            warnings?.log("`algorithm` is required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

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

    public var jsonObject: [String: JSONValue] {
        .init([
            "algorithm": algorithm,
            "compression": compression,
            "originalLength": originalLength,
            "profile": profile,
            "scheme": scheme,
        ])
    }
}
