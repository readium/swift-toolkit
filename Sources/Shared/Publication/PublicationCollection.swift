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

    public init(metadata: [String: Any] = [:], links: [Link], subcollections: [String: [PublicationCollection]] = [:]) {
        metadataJSON = JSONDictionary(metadata) ?? JSONDictionary()
        self.links = links
        self.subcollections = subcollections
    }

    public init?(
        json: Any,
        warnings: WarningLogger? = nil
    ) throws {
        // Unwrap JSONValue
        var json = json
        if let j = json as? JSONValue {
            json = j.any
        }

        // Parses a list of links.
        if let array = json as? [Any] {
            self.init(links: .init(json: array, warnings: warnings))

            // Parses a Collection object.
        } else if var jsonDict = JSONDictionary(json) {
            self.init(
                metadata: (jsonDict.pop("metadata")?.object ?? [:]).mapValues { $0 as Any },
                links: .init(json: jsonDict.pop("links")),
                subcollections: Self.makeCollections(json: jsonDict.json)
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
            "links": encodeIfNotEmpty(links.json),
        ] as [String: JSONValue], additional: Self.serializeCollections(subcollections))
    }

    static func makeCollections(json: Any?, warnings: WarningLogger? = nil) -> [String: [PublicationCollection]] {
        // Handle JSONValue
        var json = json
        if let j = json as? JSONValue {
            json = j.any
        }

        // Handle [String: JSONValue] explicitly
        if let dict = json as? [String: JSONValue] {
            return dict.compactMapValues { json in
                if let collection = try? PublicationCollection(json: json, warnings: warnings) {
                    return [collection]
                } else if case let .array(arr) = json {
                    return arr.compactMap { try? PublicationCollection(json: $0, warnings: warnings) }
                } else {
                    return nil
                }
            }
        }

        guard let json = json as? [String: Any] else {
            return [:]
        }

        return json.compactMapValues { json in
            // Parses list of links or a single collection object.
            if let collection = try? PublicationCollection(json: json, warnings: warnings) {
                return [collection]

                // Parses list of collection objects.
            } else if let collections = json as? [Any] {
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
                return .object(collections[0].json)
            } else {
                return .array(collections.map { .object($0.json) })
            }
        }
    }
}
