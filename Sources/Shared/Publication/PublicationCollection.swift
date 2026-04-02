//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Core Collection Model
/// https://readium.org/webpub-manifest/schema/subcollection.schema.json
/// Can be used as extension point in the Readium Web Publication Manifest.
public struct PublicationCollection: Hashable, Sendable, JSONValueDecodable, JSONObjectEncodable {
    public var metadata: [String: JSONValue]

    public var links: [Link]

    /// Subcollections indexed by their role in this collection.
    public var subcollections: [String: [PublicationCollection]]

    public init(metadata: [String: JSONValue] = [:], links: [Link], subcollections: [String: [PublicationCollection]] = [:]) {
        self.metadata = metadata
        self.links = links
        self.subcollections = subcollections
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }

        if let array = json.array {
            // Parses a list of links.
            self.init(links: array.decode(warnings: warnings))
        } else if var jsonObject = json.object {
            // Parses a Collection object.
            self.init(
                metadata: jsonObject.pop("metadata")?.object ?? [:],
                links: jsonObject.pop("links")?.decode(warnings: warnings) ?? [],
                subcollections: Self.makeCollections(json: .object(jsonObject), warnings: warnings)
            )
        } else {
            self.init(links: [])
        }

        guard !links.isEmpty else {
            warnings?.log("`links` should not be empty", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "metadata": metadata.orNullIfEmpty,
            "links": links.orNullIfEmpty,
        ], adding: Self.serializeCollections(subcollections))
    }

    static func makeCollections(json: JSONValue?, warnings: WarningLogger? = nil) -> [String: [PublicationCollection]] {
        guard let jsonObject = json?.object else {
            return [:]
        }

        return jsonObject.compactMapValues { json in
            // Parses list of links or a single collection object.
            if let collection: PublicationCollection = try? json.decode(warnings: warnings) {
                return [collection]
            } else if let collectionsArray = json.array {
                // Parses list of collection objects.
                let collections: [PublicationCollection] = collectionsArray.decode(warnings: warnings)
                return collections.isEmpty ? nil : collections
            } else {
                return nil
            }
        }
    }

    static func serializeCollections(_ collections: [String: [PublicationCollection]]) -> [String: JSONValue] {
        collections.compactMapValues { collections in
            if collections.isEmpty {
                return nil
            } else if collections.count == 1 {
                return collections[0].jsonValue
            } else {
                return collections.jsonValue
            }
        }
    }
}
