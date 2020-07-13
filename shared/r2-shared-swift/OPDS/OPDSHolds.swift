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
    
    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        if json == nil {
            return nil
        }
        guard let jsonObject = json as? [String: Any] else {
            warnings?.log("Invalid Holds object", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }
        
        self.init(
            total: parsePositive(jsonObject["total"]),
            position: parsePositive(jsonObject["position"])
        )
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "total": encodeIfNotNil(total),
            "position": encodeIfNotNil(position)
        ])
    }
    
}
