//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// OPDS Acquisition Object
/// https://drafts.opds.io/schema/acquisition-object.schema.json
public struct OPDSAcquisition: Equatable {
    public var type: String
    public var children: [OPDSAcquisition] = []

    public var mediaType: MediaType? { MediaType(type) }

    public init(type: String, children: [OPDSAcquisition] = []) {
        self.type = type
        self.children = children
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        guard let jsonObject = json as? [String: Any],
              let type = jsonObject["type"] as? String
        else {
            warnings?.log("`type` is required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        self.type = type
        children = [OPDSAcquisition](json: jsonObject["child"], warnings: warnings)
    }

    public var json: [String: Any] {
        makeJSON([
            "type": type,
            "child": encodeIfNotEmpty(children.json),
        ])
    }
}

public extension Array where Element == OPDSAcquisition {
    /// Parses multiple JSON acquisitions into an array of OPDSAcquisitions.
    /// eg. let acquisitions = [OPDSAcquisition](json: [...])
    init(json: Any?, warnings: WarningLogger? = nil) {
        self.init()
        guard let json = json as? [[String: Any]] else {
            return
        }

        let acquisitions = json.compactMap { try? OPDSAcquisition(json: $0, warnings: warnings) }
        append(contentsOf: acquisitions)
    }

    var json: [[String: Any]] {
        map(\.json)
    }
}
