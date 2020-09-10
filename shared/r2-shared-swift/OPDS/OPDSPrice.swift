//
//  OPDSPrice.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 12.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// The price of a publication in an OPDS link.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSPrice: Equatable {
    
    public var currency: String  // eg. EUR
    
    // Should only be used for display purposes, because of precision issues inherent with Double and the JSON parsing.
    public var value: Double
    
    public init(currency: String, value: Double) {
        self.currency = currency
        self.value = value
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard let json = json as? [String: Any],
            let currency = json["currency"] as? String,
            let value = parsePositiveDouble(json["value"]) else
        {
            throw JSONError.parsing(OPDSPrice.self)
        }
        
        self.currency = currency
        self.value = value
    }
    
    public var json: [String: Any] {
        return [
            "currency": currency,
            "value": value
        ]
    }
    
}
