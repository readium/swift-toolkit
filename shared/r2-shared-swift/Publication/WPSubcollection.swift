//
//  WPSubcollection.swift
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
public struct WPSubcollection: Equatable {
    
    /// JSON key used to reference this collection in its parent.
    public var role: String
    
    public var metadata: [String: Any] = [:]
    public var links: [Link] = []
    public var subcollections: [WPSubcollection] = []
    
    public init(role: String, metadata: [String: Any] = [:], links: [Link], subcollections: [WPSubcollection] = []) {
        self.role = role
        self.metadata = metadata
        self.links = links
        self.subcollections = subcollections
    }
    
    public init(role: String, json: Any) throws {
        self.role = role
        
        // Parses a list of links.
        if let json = json as? [[String: Any]] {
            self.links = [Link](json: json)

        // Parses a sub-collection object.
        } else if var json = JSONDictionary(json) {
            self.metadata = json.pop("metadata") as? [String: Any] ?? [:]
            self.links = [Link](json: json.pop("links"))
            self.subcollections = [WPSubcollection](json: json.json)
        }

        guard !links.isEmpty else {
            throw JSONParsingError.subcollection
        }
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "metadata": encodeIfNotEmpty(metadata),
            "links": links.json,
        ], additional: subcollections.json)
    }
    
    public static func == (lhs: WPSubcollection, rhs: WPSubcollection) -> Bool {
        guard #available(iOS 11.0, *) else {
            // The JSON comparison is not reliable before iOS 11, because the keys order is not deterministic. Since the equality is only tested during unit tests, it's not such a problem.
            return false
        }
        
        let lMetadata = try? JSONSerialization.data(withJSONObject: lhs.metadata, options: [.sortedKeys])
        let rMetadata = try? JSONSerialization.data(withJSONObject: rhs.metadata, options: [.sortedKeys])
        return lMetadata == rMetadata
            && lhs.role == rhs.role
            && lhs.links == rhs.links
            && lhs.subcollections == rhs.subcollections
    }
    
}

/// Syntactic sugar to parse multiple JSON subcollections into an array of WPSubcollections.
/// eg. let subcollections = [WPSubcollection](json: [...])
extension Array where Element == WPSubcollection {
    
    public init(json: Any?) {
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
            if let subcollection = try? WPSubcollection(role: role, json: subJSON) {
                append(subcollection)
                
            // Parses list of collection objects.
            } else if let subsJSON = subJSON as? [[String: Any]] {
                let subcollections = subsJSON.compactMap { try? WPSubcollection(role: role, json: $0) }
                append(contentsOf: subcollections)
            }
        }
    }
    
    public var json: [String: Any] {
        // Groups the sub-collections by their role.
        let dict = Dictionary(grouping: self, by: { $0.role } )
            .mapValues { subcollections -> Any in
                if subcollections.count == 1, let subcollection = subcollections.first {
                    return subcollection.json
                } else {
                    return subcollections.map { $0.json }
                }
            }
        
        return dict
    }
    
}
