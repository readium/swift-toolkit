//
//  PotentialRights.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/13/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SwiftyJSON

struct PotentialRights {
    /// Time and Date when the license ends.
    var end: Date?

    init(with json: JSON) {
        if let endString = json["end"].string,
            let endDate = endString.dateFromISO8601
        {
            end = endDate
        }
    }
}
