//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Library-specific features when a specific book is unavailable but provides a hold list.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSHolds: Equatable {
    public let total: Int?
    public let position: Int?

    public init(total: Int?, position: Int?) {
        self.total = total
        self.position = position
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        if json == nil {
            return nil
        }
        guard let jsonObject = json as? [String: Any] else {
            warnings?.log("Invalid Holds object", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            total: parsePositive(jsonObject["total"]),
            position: parsePositive(jsonObject["position"])
        )
    }

    public var json: [String: Any] {
        makeJSON([
            "total": encodeIfNotNil(total),
            "position": encodeIfNotNil(position),
        ])
    }
}
