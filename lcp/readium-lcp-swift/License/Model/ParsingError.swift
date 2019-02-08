//
//  ParsingError.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/14/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

enum ParsingError: Error {
    case json
    case date
    case link
    case updated
    case updatedDate
    case encryption
    case signature

}

extension ParsingError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .json:
            return "The JSON is no representing a valid Status Document."
        case .date:
            return "Invalid ISO8601 dates found."
        case .link:
            return "Invalid Link found in the JSON."
        case .encryption:
            return "Invalid Encryption object."
        case .signature:
            return "Invalid License Document Signature."
        case .updated:
            return "Invalid Updated object."
        case .updatedDate:
            return "Invalid Updated object date."
        }
    }
    
}
