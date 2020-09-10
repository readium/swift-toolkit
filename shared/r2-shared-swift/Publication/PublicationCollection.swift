//
//  PublicationCollection.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Core Collection Model
/// https://readium.org/webpub-manifest/schema/subcollection.schema.json
/// Can be used as extension point in the Readium Web Publication Manifest.
public struct PublicationCollection: JSONEquatable {
    
    /// JSON key used to reference this collection in its parent.
    public let role: String
    
    public let metadata: [String: Any]
    public let links: [Link]
    public let otherCollections: [PublicationCollection]
    
    public init(role: String, metadata: [String: Any] = [:], links: [Link], otherCollections: [PublicationCollection] = []) {
        self.role = role
        self.metadata = metadata
        self.links = links
        self.otherCollections = otherCollections
    }
    
    public init(role: String, json: Any, normalizeHref: (String) -> String = { $0 }) throws {
        // Parses a list of links.
        if let json = json as? [[String: Any]] {
            self.init(
                role: role,
                links: .init(json: json, normalizeHref: normalizeHref)
            )

        // Parses a sub-collection object.
        } else if var json = JSONDictionary(json) {
            self.init(
                role: role,
                metadata: json.pop("metadata") as? [String: Any] ?? [:],
                links: .init(json: json.pop("links"), normalizeHref: normalizeHref),
                otherCollections: .init(json: json.json, normalizeHref: normalizeHref)
            )
            
        } else {
            self.init(role: role, links: [])
        }

        guard !links.isEmpty else {
            throw JSONError.parsing(PublicationCollection.self)
        }
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "metadata": encodeIfNotEmpty(metadata),
            "links": links.json,
        ], additional: otherCollections.json)
    }
    
    public static func == (lhs: PublicationCollection, rhs: PublicationCollection) -> Bool {
        guard #available(iOS 11.0, *) else {
            // The JSON comparison is not reliable before iOS 11, because the keys order is not deterministic. Since the equality is only tested during unit tests, it's not such a problem.
            return false
        }
        
        let lMetadata = try? JSONSerialization.data(withJSONObject: lhs.metadata, options: [.sortedKeys])
        let rMetadata = try? JSONSerialization.data(withJSONObject: rhs.metadata, options: [.sortedKeys])
        return lMetadata == rMetadata
            && lhs.role == rhs.role
            && lhs.links == rhs.links
            && lhs.otherCollections == rhs.otherCollections
    }
    
}

/// Syntactic sugar to parse multiple JSON collections into an array of PublicationCollections.
/// eg. let collections = [PublicationCollection](json: [...])
extension Array where Element == PublicationCollection {
    
    public init(json: Any?, normalizeHref: (String) -> String = { $0 }) {
        self.init()
        guard let json = json as? [String: Any] else {
            return
        }
        
        let roles = json.keys.sorted()
        for role in roles {
            guard let subJSON = json[role] else {
                continue
            }
            
            // Parses list of links or a single collection object.
            if let collection = try? PublicationCollection(role: role, json: subJSON, normalizeHref: normalizeHref) {
                append(collection)
                
            // Parses list of collection objects.
            } else if let subsJSON = subJSON as? [[String: Any]] {
                let collections = subsJSON.compactMap { try? PublicationCollection(role: role, json: $0, normalizeHref: normalizeHref) }
                append(contentsOf: collections)
            }
        }
    }
    
    public var json: [String: Any] {
        // Groups the sub-collections by their role.
        let dict = Dictionary(grouping: self, by: { $0.role } )
            .mapValues { collections -> Any in
                if collections.count == 1, let collection = collections.first {
                    return collection.json
                } else {
                    return collections.map { $0.json }
                }
            }
        
        return dict
    }
    
    public func first(withRole role: String) -> PublicationCollection? {
        return first { $0.role == role }
    }
    
    public func all(withRole role: String) -> [PublicationCollection] {
        return filter { $0.role == role }
    }

}
