//
//  WebPublication.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Model for the Readium Web Publication
/// See. https://readium.org/webpub-manifest/
///
/// Extension properties for EPUB, OPDF, etc. are available under Extensions/.
public class WebPublication: JSONEquatable {

    public var context: [String]  // @context
    public var metadata: Metadata
    public var links: [Link]
    public var readingOrder: [Link]
    public var resources: [Link]
    public var tableOfContents: [Link]
    public var otherCollections: [PublicationCollection]
    
    
    public init(context: [String] = [], metadata: Metadata, links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = [], tableOfContents: [Link] = [], otherCollections: [PublicationCollection] = []) {
        self.context = context
        self.metadata = metadata
        self.links = links
        self.readingOrder = readingOrder
        self.resources = resources
        self.tableOfContents = tableOfContents
        self.otherCollections = otherCollections
    }
    
    /// Parses a Readium Web Publication Manifest.
    /// https://readium.org/webpub-manifest/schema/publication.schema.json
    public init(json: Any, normalizeHref: (String) -> String = { $0 }) throws {
        guard var json = JSONDictionary(json) else {
            throw JSONError.parsing(WebPublication.self)
        }
        
        self.context = parseArray(json.pop("@context"), allowingSingle: true)
        self.metadata = try Metadata(json: json.pop("metadata"), normalizeHref: normalizeHref)
        self.otherCollections = []
        self.links = [Link](json: json.pop("links"), normalizeHref: normalizeHref)
            .filter { !$0.rels.isEmpty }
        // `readerOrder` used to be `spine`, so we parse `spine` as a fallback.
        self.readingOrder = [Link](json: json.pop("readingOrder") ?? json.pop("spine"), normalizeHref: normalizeHref)
            .filter { $0.type != nil }
        self.resources = [Link](json: json.pop("resources"), normalizeHref: normalizeHref)
            .filter { $0.type != nil }
        self.tableOfContents = [Link](json: json.pop("toc"), normalizeHref: normalizeHref)

        // Parses sub-collections from remaining JSON properties.
        self.otherCollections = [PublicationCollection](json: json.json, normalizeHref: normalizeHref)
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "@context": encodeIfNotEmpty(context),
            "metadata": metadata.json,
            "links": links.json,
            "readingOrder": readingOrder.json,
            "resources": encodeIfNotEmpty(resources.json),
            "toc": encodeIfNotEmpty(tableOfContents.json),
        ], additional: otherCollections.json)
    }
    
    /// Returns the Manifest's data JSON representation.
    public var manifest: Data? {
        return serializeJSONData(json)
    }
    
    
    /// Replaces the links for the first found subcollection with the given role.
    /// If none is found, creates a new subcollection.
    func setCollectionLinks(_ links: [Link], forRole role: String) {
        if let collection = otherCollections.first(withRole: role) {
            collection.links = links
        } else {
            otherCollections.append(PublicationCollection(role: role, links: links))
        }
    }
    
}
