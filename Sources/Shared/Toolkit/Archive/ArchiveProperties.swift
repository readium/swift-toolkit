//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Holds information about how the resource is stored in the archive.
public struct ArchiveProperties: Equatable, JSONValueDecodable, JSONObjectEncodable {
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

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }
        guard
            let jsonObject = json.object,
            let length: UInt64 = jsonObject["entryLength"]?.nonNegative(),
            let isEntryCompressed = jsonObject["isEntryCompressed"]?.bool
        else {
            throw JSONError.parsing(Self.self)
        }

        self.init(
            entryLength: length,
            isEntryCompressed: isEntryCompressed
        )
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "entryLength": entryLength,
            "isEntryCompressed": isEntryCompressed,
        ])
    }
}

private let archiveKey = "https://readium.org/webpub-manifest/properties#archive"

public extension ResourceProperties {
    /// Provides information about how the resource is stored in the publication archive.
    var archive: ArchiveProperties? {
        get { self[archiveKey] }
        set { self[archiveKey] = newValue }
    }
}
