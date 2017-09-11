//
//  LcpError.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// Errors associated to LCP module.
public enum LcpError: Error {
    case json
    case date
    case link
    case updated
    case updatedDate
    case encryption
    case signature

    public var localizedDescription: String {
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
