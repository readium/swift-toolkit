//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Locator: Codable {
    public init(from decoder: Decoder) throws {
        let json = try decoder.singleValueContainer().decode(String.self)
        try self.init(jsonString: json)!
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(jsonString)
    }
}
