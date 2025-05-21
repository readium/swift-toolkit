//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds information about how the resource is stored in the archive.
public struct ArchiveProperties: Equatable {
    /// The length of the entry stored in the archive. It might be a compressed
    /// length if the entry is deflated.
    public let entryLength: UInt64

    /// Indicates whether the entry was compressed before being stored in the
    /// archive.
    public let isEntryCompressed: Bool

    public init(entryLength: UInt64, isEntryCompressed: Bool) {
        self.entryLength = entryLength
        self.isEntryCompressed = isEntryCompressed
    }

    init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard
            let jsonObject = json as? [String: Any],
            let length: UInt64 = (jsonObject["entryLength"] as? NSNumber)?.uint64Value,
            length >= 0,
            let isEntryCompressed = jsonObject["isEntryCompressed"] as? Bool
        else {
            throw JSONError.parsing(Self.self)
        }

        self.init(
            entryLength: length,
            isEntryCompressed: isEntryCompressed
        )
    }

    var json: [String: Any] {
        [
            "entryLength": entryLength as NSNumber,
            "isEntryCompressed": isEntryCompressed,
        ]
    }
}

private let archiveKey = "https://readium.org/webpub-manifest/properties#archive"

public extension ResourceProperties {
    /// Provides information about how the resource is stored in the publication archive.
    var archive: ArchiveProperties? {
        get {
            try? ArchiveProperties(json: properties[archiveKey])
        }
        set {
            if let archive = newValue {
                properties[archiveKey] = archive.json
            } else {
                properties.removeValue(forKey: archiveKey)
            }
        }
    }
}
