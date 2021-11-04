//
//  Signature.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Signature allowing to certify the License Document integrity.
public struct Signature {
    /// Algorithm used to calculate the signature, identified using the URIs given in [XML-SIG]. This MUST match the signature algorithm named in the Encryption Profile identified in `encryption/profile`.
    public let algorithm: String
    /// The Provider Certificate: an X509 certificate used by the Content Provider.
    public let certificate: String
    /// Value of the signature.
    public let value: String

    init(json: [String: Any]) throws {
        guard let algorithm = json["algorithm"] as? String,
            let certificate = json["certificate"] as? String,
            let value = json["value"] as? String else
        {
            throw ParsingError.signature
        }
        
        self.algorithm = algorithm
        self.certificate = certificate
        self.value = value
    }
    
}
