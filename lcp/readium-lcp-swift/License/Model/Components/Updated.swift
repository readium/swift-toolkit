//
//  Updated.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SwiftyJSON

class Updated {
    /// Time and Date when the License Document was last updated.
    var license: Date
    /// Time and Date when the Status Document was last updated.
    var status: Date

    init(with json: JSON) throws {
        guard let license = json["license"].string,
            let status = json["status"].string else {
                throw ParsingError.updated
        }
        guard let licenseDate = license.dateFromISO8601,
            let statusDate = status.dateFromISO8601 else {
                throw ParsingError.updatedDate
        }
        self.license = licenseDate
        self.status = statusDate
    }
}
