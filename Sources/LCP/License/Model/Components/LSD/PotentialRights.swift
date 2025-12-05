//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct PotentialRights {
    /// Time and Date when the license ends.
    public let end: Date?

    init(json: [String: Any]) throws {
        end = (json["end"] as? String)?.dateFromISO8601
    }
}
