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

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        guard let json = json else {
            return nil
        }
        guard
            let jsonObject = json.object,
            let length = jsonObject["entryLength"]?.double.flatMap({ UInt64($0) }),
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
            "entryLength": Double(entryLength),
            "isEntryCompressed": isEntryCompressed,
        ])
    }
}

private let archiveKey = "https://readium.org/webpub-manifest/properties#archive"

public extension ResourceProperties {
    /// Provides information about how the resource is stored in the publication archive.
    var archive: ArchiveProperties? {
        get {
            try? ArchiveProperties(json: JSONValue.wrap(properties[archiveKey]))
        }
        set {
            if let archive = newValue {
                properties[archiveKey] = archive.jsonObject
            } else {
                properties.removeValue(forKey: archiveKey)
            }
        }
    }
}

public extension JSONValue {
    /// Safely wraps a standard `Any` (like those from JSONSerialization or older dictionaries) into a type-safe `JSONValue`
    static func wrap(_ any: Any?) -> JSONValue? {
        guard let any = any else { return nil }

        if any is NSNull {
            return .null
        }

        switch any {
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .integer(int)
        case let double as Double:
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.compactMap { JSONValue.wrap($0) })
        case let dict as [String: Any]:
            return .object(dict.compactMapValues { JSONValue.wrap($0) })
        default:
            return nil
        }
    }
}
