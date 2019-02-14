//
//  ParsingError.swift
//  r2-lcp-swift
//
//  Created by Alexandre Camilleri on 9/14/17.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum ParsingError: Error {
    case malformedJSON
    case licenseDocument
    case statusDocument
    case link
    case encryption
    case signature
    case event
    case url(rel: String)
}

extension ParsingError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .malformedJSON:
            return "The JSON is malformed and can't be parsed."
        case .licenseDocument:
            return "The JSON is not representing a valid License Document."
        case .statusDocument:
            return "The JSON is not representing a valid Status Document."
        case .link:
            return "Invalid Link."
        case .encryption:
            return "Invalid Encryption."
        case .signature:
            return "Invalid License Document Signature."
        case .event:
            return "Invalid Event."
        case .url(let rel):
            return "Invalid URL for link with rel \(rel)."
        }
    }
    
}
