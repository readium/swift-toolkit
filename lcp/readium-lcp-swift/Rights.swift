//
//  Rights.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SwiftyJSON

public struct Rights {
    /// Maximum number of pages that can be printed over the lifetime of the
    /// license.
    var print: Int?
    /// Maximum number of characters that can be copied to the clipboard
    /// over the lifetime of the license.
    var copy: Int?
    /// Date and time when the license begins.
    var start: Date?
    /// Date and time when the license ends.
    var end: Date?
    /// Possible extenssion date. Set to end + 1 month by default.
    var potentialEnd: Date?

    init(with json: JSON) {
        print = json["print"].int
        copy = json["copy"].int
        if let start = json["start"].string,
            let startDate = start.dateFromISO8601
        {
            self.start = startDate
        }
        if let end =  json["end"].string,
            let endDate = end.dateFromISO8601
        {
            self.end = endDate
            self.potentialEnd = Calendar.current.date(byAdding: .month,
                                                      value: 1,
                                                      to: endDate)
        }
    }
}
