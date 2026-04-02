//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public struct PotentialRights: JSONValueDecodable {
    /// Time and Date when the license ends.
    public let end: Date?

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        let json = json?.jsonValue.object
        end = json?["end"]?.date
    }
}
