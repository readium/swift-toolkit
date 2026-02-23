//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Archive Link Properties Extension
public extension Properties {
    /// Holds information about how the resource is stored in the publication archive.
    struct Archive: Equatable {
        /// The length of the entry stored in the archive. It might be a compressed length if the entry is deflated.
        public let entryLength: UInt64
        /// Indicates whether the entry was compressed before being stored in the archive.
        public let isEntryCompressed: Bool

        public init(entryLength: UInt64, isEntryCompressed: Bool) {
            self.entryLength = entryLength
            self.isEntryCompressed = isEntryCompressed
        }

        public init?(json: Any?, warnings: WarningLogger? = nil) throws {
            if json == nil {
                return nil
            }
            guard
                let jsonObject = JSONDictionary(json)?.json,
                let length = jsonObject["entryLength"]?.uint64,
                let isCompressed = jsonObject["isEntryCompressed"]?.bool
            else {
                warnings?.log("`entryLength` and `isEntryCompressed` are required", model: Self.self, source: json)
                throw JSONError.parsing(Self.self)
            }

            self.init(
                entryLength: length,
                isEntryCompressed: isCompressed
            )
        }

        public var json: [String: JSONValue] {
            [
                "entryLength": .uint64(entryLength),
                "isEntryCompressed": .bool(isEntryCompressed),
            ]
        }
    }

    /// Provides information about how the resource is stored in the publication archive.
    var archive: Archive? {
        try? Archive(json: otherProperties["https://readium.org/webpub-manifest/properties#archive"], warnings: self)
    }
}
