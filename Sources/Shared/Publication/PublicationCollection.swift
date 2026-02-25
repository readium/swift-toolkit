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
public struct PublicationCollection: JSONEquatable, Hashable, Sendable {
    public var metadata: [String: JSONValue] {
        get { metadataJSON.json }
        set { metadataJSON = JSONDictionary(newValue) ?? JSONDictionary() }
    }

    public var links: [Link]

    /// Subcollections indexed by their role in this collection.
    public var subcollections: [String: [PublicationCollection]]

    /// Trick to keep the struct hashable despite [String: Any]
    private var metadataJSON: JSONDictionary

    public init(metadata: [String: JSONValue] = [:], links: [Link], subcollections: [String: [PublicationCollection]] = [:]) {
        metadataJSON = JSONDictionary(metadata) ?? JSONDictionary()
        self.links = links
        self.subcollections = subcollections
    }

    public init?(
        json: JSONValue?,
        warnings: WarningLogger? = nil
    ) throws {
        guard let json = json else {
            return nil
        }

        // Parses a list of links.
        if case let .array(array) = json {
            self.init(links: .init(json: array.map(\.any), warnings: warnings))

            // Parses a Collection object.
        } else if var jsonDict = JSONDictionary(json) {
            self.init(
                metadata: jsonDict.pop("metadata")?.object ?? [:],
                links: .init(json: jsonDict.pop("links")),
                subcollections: Self.makeCollections(json: .object(jsonDict.json))
            )

        } else {
            self.init(links: [])
        }

        guard !links.isEmpty else {
            warnings?.log("`links` should not be empty", model: Self.self, source: json.any, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
    }

    public init?(
        json: Any,
        warnings: WarningLogger? = nil
    ) throws {
        try self.init(json: JSONValue(json), warnings: warnings)
    }

    public var json: JSONDictionary.Wrapped {
        makeJSON([
            "metadata": encodeIfNotEmpty(metadata),
            "links": encodeIfNotEmpty(links.json),
        ] as [String: JSONValue], additional: Self.serializeCollections(subcollections))
    }

    static func makeCollections(json: JSONValue?, warnings: WarningLogger? = nil) -> [String: [PublicationCollection]] {
        guard let json = json?.object else {
            return [:]
        }

        return json.compactMapValues { json in
            // Parses list of links or a single collection object.
            if let collection = try? PublicationCollection(json: json, warnings: warnings) {
                return [collection]

                // Parses list of collection objects.
            } else if case let .array(collections) = json {
                let collections = collections.compactMap {
                    try? PublicationCollection(json: $0, warnings: warnings)
                }
                return collections.isEmpty ? nil : collections

            } else {
                return nil
            }
        }
    }

    static func makeCollections(json: Any?, warnings: WarningLogger? = nil) -> [String: [PublicationCollection]] {
        makeCollections(json: JSONValue(json), warnings: warnings)
    }

    static func serializeCollections(_ collections: [String: [PublicationCollection]]) -> JSONDictionary.Wrapped {
        collections.compactMapValues { collections in
            if collections.isEmpty {
                return nil
            } else if collections.count == 1 {
                return .object(collections[0].json)
            } else {
                return .array(collections.map { .object($0.json) })
            }
        }
    }
}
