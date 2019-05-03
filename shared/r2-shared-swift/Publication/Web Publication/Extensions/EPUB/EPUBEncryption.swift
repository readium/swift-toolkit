//
//  EPUBEncryption.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Indicates that a resource is encrypted/obfuscated and provides relevant information for decryption.
public struct EPUBEncryption: Equatable {
    
    /// Identifies the algorithm used to encrypt the resource.
    public var algorithm: String  // URI
    
    /// Compression method used on the resource.
    public var compression: String?
    
    /// Original length of the resource in bytes before compression and/or encryption.
    public var originalLength: Int?
    
    /// Identifies the encryption profile used to encrypt the resource.
    public var profile: String?  // URI
    
    /// Identifies the encryption scheme used to encrypt the resource.
    public var scheme: String?  // URI
    
    
    public init(algorithm: String, compression: String? = nil, originalLength: Int? = nil, profile: String? = nil, scheme: String? = nil) {
        self.algorithm = algorithm
        self.compression = compression
        self.originalLength = originalLength
        self.profile = profile
        self.scheme = scheme
    }
    
    public init?(json: Any?) throws {
        // Convenience when parsing parent structures.
        if json == nil {
            return nil
        }
        guard let json = json as? [String: Any],
            let algorithm = json["algorithm"] as? String else
        {
            throw JSONError.parsing(EPUBEncryption.self)
        }
        
        self.algorithm = algorithm
        self.compression = json["compression"] as? String
        self.originalLength = json["original-length"] as? Int
        self.profile = json["profile"] as? String
        self.scheme = json["scheme"] as? String
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "algorithm": algorithm,
            "compression": encodeIfNotNil(compression),
            "original-length": encodeIfNotNil(originalLength),
            "profile": encodeIfNotNil(profile),
            "scheme": encodeIfNotNil(scheme)
        ])
    }
    
}
