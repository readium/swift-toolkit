//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Library-specific feature that contains information about the copies that a library has acquired.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSCopies: Equatable, JSONValueDecodable, JSONObjectEncodable {
    public let total: Int?
    public let available: Int?

    public init(total: Int?, available: Int?) {
        self.total = total
        self.available = available
    }

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        guard let json = json else {
            return nil
        }
        guard let jsonObject = json.object else {
            warnings?.log("Invalid Copies object", model: Self.self, source: json.any)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            total: jsonObject["total"]?.parsePositive(),
            available: jsonObject["available"]?.parsePositive()
        )
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "total": total,
            "available": available,
        ])
    }
}
