//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// OPDS Acquisition Object
/// https://drafts.opds.io/schema/acquisition-object.schema.json
public struct OPDSAcquisition: Equatable, JSONObjectEncodable, JSONValueDecodable {
    public var type: String
    public var children: [OPDSAcquisition] = []

    public var mediaType: MediaType? {
        MediaType(type)
    }

    public init(type: String, children: [OPDSAcquisition] = []) {
        self.type = type
        self.children = children
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        let json = json?.jsonValue

        guard
            let jsonObject = json?.object,
            let type = jsonObject["type"]?.string
        else {
            warnings?.log("`type` is required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        self.type = type
        children = jsonObject["child"]?.decode(warnings: warnings) ?? []
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "type": type,
            "child": children.orNullIfEmpty,
        ])
    }
}
