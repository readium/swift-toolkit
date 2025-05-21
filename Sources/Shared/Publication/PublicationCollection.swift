//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Core Collection Model
/// https://readium.org/webpub-manifest/schema/subcollection.schema.json
/// Can be used as extension point in the Readium Web Publication Manifest.
public struct PublicationCollection: JSONEquatable, Hashable, Sendable {
    public var metadata: [String: Any] {
        get { metadataJSON.json }
        set { metadataJSON = JSONDictionary(newValue) ?? JSONDictionary() }
    }

    public var links: [Link]

    /// Subcollections indexed by their role in this collection.
    public var subcollections: [String: [PublicationCollection]]

    // Trick to keep the struct hashable despite [String: Any]
    private var metadataJSON: JSONDictionary

    public init(metadata: [String: Any] = [:], links: [Link], subcollections: [String: [PublicationCollection]] = [:]) {
        metadataJSON = JSONDictionary(metadata) ?? JSONDictionary()
        self.links = links
        self.subcollections = subcollections
    }

    public init?(
        json: Any,
        warnings: WarningLogger? = nil
    ) throws {
        // Parses a list of links.
        if let json = json as? [JSONDictionary.Wrapped] {
            self.init(links: .init(json: json, warnings: warnings))

            // Parses a Collection object.
        } else if var json = JSONDictionary(json) {
            self.init(
                metadata: json.pop("metadata") as? JSONDictionary.Wrapped ?? [:],
                links: .init(json: json.pop("links")),
                subcollections: Self.makeCollections(json: json.json)
            )

        } else {
            self.init(links: [])
        }

        guard !links.isEmpty else {
            warnings?.log("`links` should not be empty", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
    }

    public var json: JSONDictionary.Wrapped {
        makeJSON([
            "metadata": encodeIfNotEmpty(metadata),
            "links": links.json,
        ], additional: Self.serializeCollections(subcollections))
    }

    public static func == (lhs: PublicationCollection, rhs: PublicationCollection) -> Bool {
        let lMetadata = try? JSONSerialization.data(withJSONObject: lhs.metadata, options: [.sortedKeys])
        let rMetadata = try? JSONSerialization.data(withJSONObject: rhs.metadata, options: [.sortedKeys])
        return lMetadata == rMetadata
            && lhs.links == rhs.links
            && lhs.subcollections == rhs.subcollections
    }

    static func makeCollections(json: Any?, warnings: WarningLogger? = nil) -> [String: [PublicationCollection]] {
        guard let json = json as? [String: Any] else {
            return [:]
        }

        return json.compactMapValues { json in
            // Parses list of links or a single collection object.
            if let collection = try? PublicationCollection(json: json, warnings: warnings) {
                return [collection]

                // Parses list of collection objects.
            } else if let collections = json as? [JSONDictionary.Wrapped] {
                return collections.compactMap {
                    try? PublicationCollection(json: $0, warnings: warnings)
                }

            } else {
                return nil
            }
        }
    }

    static func serializeCollections(_ collections: [String: [PublicationCollection]]) -> JSONDictionary.Wrapped {
        collections.compactMapValues { collections in
            if collections.isEmpty {
                return nil
            } else if collections.count == 1 {
                return collections[0].json
            } else {
                return collections.map(\.json)
            }
        }
    }
}
