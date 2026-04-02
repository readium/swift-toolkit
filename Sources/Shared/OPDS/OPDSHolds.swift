//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Library-specific features when a specific book is unavailable but provides a hold list.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSHolds: Equatable, JSONValueDecodable, JSONObjectEncodable {
    public let total: Int?
    public let position: Int?

    public init(total: Int?, position: Int?) {
        self.total = total
        self.position = position
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }
        guard let jsonObject = json.object else {
            warnings?.log("Invalid Holds object", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            total: jsonObject["total"]?.nonNegative(),
            position: jsonObject["position"]?.nonNegative()
        )
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "total": total,
            "position": position,
        ])
    }
}
