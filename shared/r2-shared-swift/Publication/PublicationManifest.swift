//
//  PublicationManifest.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 30/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Holds the metadata of a Readium publication, as described in the Readium Web Publication
/// Manifest.
///
/// See. https://readium.org/webpub-manifest/
public struct PublicationManifest: JSONEquatable {
    
    public let context: [String]  // @context
    
    public let metadata: Metadata
    
    // FIXME: should not be mutable, but we need it to set `self` in the publication server
    public var links: [Link]
    
    /// Identifies a list of resources in reading order for the publication.
    public let readingOrder: [Link]
    
    /// Identifies resources that are necessary for rendering the publication.
    public let resources: [Link]
    
    public let subcollections: [String: [PublicationCollection]]
    
    /// Identifies the collection that contains a table of contents.
    public var tableOfContents: [Link] {
        subcollections["toc"]?.first?.links ?? []
    }
    
    public init(context: [String] = [], metadata: Metadata, links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = [], tableOfContents: [Link] = [], subcollections: [String: [PublicationCollection]] = [:]) {
        // Convenience to set the table of contents during construction
        var subcollections = subcollections
        if !tableOfContents.isEmpty {
            subcollections["toc"] = [PublicationCollection(links: tableOfContents)]
        }
        
        self.context = context
        self.metadata = metadata
        self.links = links
        self.readingOrder = readingOrder
        self.resources = resources
        self.subcollections = subcollections
    }

    /// Parses a Readium Web Publication Manifest.
    /// https://readium.org/webpub-manifest/schema/publication.schema.json
    public init(json: Any, normalizeHref: (String) -> String = { $0 }) throws {
        guard var json = JSONDictionary(json) else {
            throw JSONError.parsing(Publication.self)
        }
        
        self.context = parseArray(json.pop("@context"), allowingSingle: true)
        self.metadata = try Metadata(json: json.pop("metadata"), normalizeHref: normalizeHref)
        self.links = [Link](json: json.pop("links"), normalizeHref: normalizeHref)
        // `readingOrder` used to be `spine`, so we parse `spine` as a fallback.
        self.readingOrder = [Link](json: json.pop("readingOrder") ?? json.pop("spine"), normalizeHref: normalizeHref)
            .filter { $0.type != nil }
        self.resources = [Link](json: json.pop("resources"), normalizeHref: normalizeHref)
            .filter { $0.type != nil }

        // Parses sub-collections from remaining JSON properties.
        self.subcollections = PublicationCollection.makeCollections(json: json.json, normalizeHref: normalizeHref)
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "@context": encodeIfNotEmpty(context),
            "metadata": metadata.json,
            "links": links.json,
            "readingOrder": readingOrder.json,
            "resources": encodeIfNotEmpty(resources.json),
            "toc": encodeIfNotEmpty(tableOfContents.json),
        ], additional: PublicationCollection.serializeCollections(subcollections))
    }
    
    /// Finds the first link with the given relation in the manifest's links.
    public func link(withRel rel: String) -> Link? {
        return (readingOrder + resources + links).first(withRel: rel)
    }
    
    /// Finds all the links with the given relation in the manifest's links.
    public func links(withRel rel: String) -> [Link] {
        return (readingOrder + resources + links).filter(byRel: rel)
    }

}
