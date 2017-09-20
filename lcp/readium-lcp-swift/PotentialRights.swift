//
//  PotentialRights.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/13/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct PotentialRights {
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
