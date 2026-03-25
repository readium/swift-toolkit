//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// The price of a publication in an OPDS link.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSPrice: Equatable, JSONValueDecodable, JSONObjectEncodable {
    public var currency: String // eg. EUR

    /// Should only be used for display purposes, because of precision issues inherent with Double and the JSON parsing.
    public var value: Double

    public init(currency: String, value: Double) {
        self.currency = currency
        self.value = value
    }

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        guard let json = json else {
            return nil
        }
        
        guard let jsonObject = json.object,
              let currency = jsonObject["currency"]?.string,
              let value = jsonObject["value"]?.parsePositiveDouble()
        else {
            warnings?.log("`currency` and `value` are required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        self.currency = currency
        self.value = value
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "currency": currency,
            "value": value
        ])
    }
}
