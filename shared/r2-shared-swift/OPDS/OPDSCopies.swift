//
//  OPDSCopies.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Library-specific feature that contains information about the copies that a library has acquired.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSCopies: Equatable {
    
    let total: Int?
    let available: Int?
    
    public init(total: Int?, available: Int?) {
        self.total = total
        self.available = available
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard let json = json as? [String: Any] else {
            throw JSONError.parsing(OPDSCopies.self)
        }
        
        self.init(
            total: parsePositive(json["total"]),
            available: parsePositive(json["available"])
        )
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "total": encodeIfNotNil(total),
            "available": encodeIfNotNil(available)
        ])
    }
    
}
