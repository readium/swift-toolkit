//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

public struct PotentialRights: Sendable {
    /// Time and Date when the license ends.
    public let end: Date?

    init(json: JSONValue?) throws {
        let json = JSONDictionary(json)
        end = parseDate(json?["end"])
    }

    init(json: [String: Any]) throws {
        try self.init(json: JSONValue(json))
    }
}
