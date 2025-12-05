//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Library-specific feature that contains information about the copies that a library has acquired.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSCopies: Equatable {
    public let total: Int?
    public let available: Int?

    public init(total: Int?, available: Int?) {
        self.total = total
        self.available = available
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        if json == nil {
            return nil
        }
        guard let jsonObject = json as? [String: Any] else {
            warnings?.log("Invalid Copies object", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            total: parsePositive(jsonObject["total"]),
            available: parsePositive(jsonObject["available"])
        )
    }

    public var json: [String: Any] {
        makeJSON([
            "total": encodeIfNotNil(total),
            "available": encodeIfNotNil(available),
        ])
    }
}
