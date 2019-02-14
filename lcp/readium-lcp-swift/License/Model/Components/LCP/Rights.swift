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

public struct Rights {
    
    /// Maximum number of pages that can be printed over the lifetime of the license.
    public let print: Int?
    /// Maximum number of characters that can be copied to the clipboard over the lifetime of the license.
    public let copy: Int?
    /// Date and time when the license begins.
    public let start: Date?
    /// Date and time when the license ends.
    public let end: Date?

    init(json: [String: Any]) throws {
        self.print = json["print"] as? Int
        self.copy = json["copy"] as? Int
        self.start = (json["start"] as? String)?.dateFromISO8601
        self.end = (json["end"] as? String)?.dateFromISO8601
    }
    
}
