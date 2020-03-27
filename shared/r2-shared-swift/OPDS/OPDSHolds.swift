//
//  OPDSHolds.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Library-specific features when a specific book is unavailable but provides a hold list.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSHolds: Equatable {
    
    let total: Int?
    let position: Int?

    public init(total: Int?, position: Int?) {
        self.total = total
        self.position = position
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard let json = json as? [String: Any] else {
            throw JSONError.parsing(OPDSHolds.self)
        }
        
        self.init(
            total: parsePositive(json["total"]),
            position: parsePositive(json["position"])
        )
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "total": encodeIfNotNil(total),
            "position": encodeIfNotNil(position)
        ])
    }
    
}
