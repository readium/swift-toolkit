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
import SwiftyJSON

/// Signature allowing to certify the License Document integrity.
struct Signature {
    /// Algorithm used to calculate the signature, identified using the URIs 
    /// given in [XML-SIG]. This MUST match the signature algorithm named in the
    /// Encryption Profile identified in `encryption/profile`.
    var algorithm: URL
    /// The Provider Certificate: an X509 certificate used by the Content 
    /// Provider.
    var certificate: String
    /// Value of the signature.
    var value: String

    init(with json: JSON) throws {
        guard let algorithm = json["algorithm"].url,
            let certificate = json["certificate"].string,
            let value = json["value"].string else {
                throw ParsingError.signature
        }
        self.algorithm = algorithm
        self.certificate = certificate
        self.value = value
    }
}
