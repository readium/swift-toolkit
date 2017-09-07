//
//  Updated.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

public class Updated {
    /// Time and Date when the License Document was last updated.
    public var license: Date
    /// Time and Date when the Status Document was last updated.
    public var status: Date

    init(with json: JSON) throws {
        guard let license = json["license"].string,
            let status = json["status"].string else {
                throw LsdError.json
        }
        guard let licenseDate = license.dateFromISO8601,
            let statusDate = status.dateFromISO8601 else {
                throw LsdError.date
        }
        
        self.license = licenseDate
        self.status = statusDate
    }
}
