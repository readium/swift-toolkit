//
//  DateExtension.swift
//  R2Shared
//
//  Created by Alexandre Camilleri on 3/22/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

extension Date {
    /// Computed property turning an ISO8601 Date to a String?.
    var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}
