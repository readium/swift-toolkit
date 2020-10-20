//
//  Manifest.swift
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
public struct Manifest: JSONEquatable, Hashable {
    
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
    ///
    /// If a non-fatal parsing error occurs, it will be logged through `warnings`.
    public init(json: Any, isPackaged: Bool = false, warnings: WarningLogger? = nil) throws {
        guard var json = JSONDictionary(json) else {
            throw JSONError.parsing(Publication.self)
        }
        
        let baseHREF = isPackaged ? "/" : (
            [Link](json: json.json["links"], warnings: warnings)
                .first(withRel: .self)
                .flatMap { URL(string: $0.href) }?
                .absoluteString
                ?? "/"
        )
        
        let normalizer = HREF.normalizer(relativeTo: baseHREF)

        self.context = parseArray(json.pop("@context"), allowingSingle: true)
        self.metadata = try Metadata(json: json.pop("metadata"), warnings: warnings, normalizeHREF: normalizer)
        
        self.links = [Link](json: json.pop("links"), warnings: warnings, normalizeHREF: normalizer)
            // If the manifest is packaged, replace any `self` link by an `alternate`.
            .map { link in
                (isPackaged && link.rels.contains(.self))
                    ? link.copy(rels: link.rels.removing(.self).appending(.alternate))
                    : link
            }
        
        // `readingOrder` used to be `spine`, so we parse `spine` as a fallback.
        self.readingOrder = [Link](json: json.pop("readingOrder") ?? json.pop("spine"), warnings: warnings, normalizeHREF: normalizer)
            .filter { $0.type != nil }
        self.resources = [Link](json: json.pop("resources"), warnings: warnings, normalizeHREF: normalizer)
            .filter { $0.type != nil }

        // Parses sub-collections from remaining JSON properties.
        self.subcollections = PublicationCollection.makeCollections(json: json.json, warnings: warnings, normalizeHREF: normalizer)
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
    public func link(withRel rel: LinkRelation) -> Link? {
        return readingOrder.first(withRel: rel)
            ?? resources.first(withRel: rel)
            ?? links.first(withRel: rel)
    }
    
    /// Finds all the links with the given relation in the manifest's links.
    public func links(withRel rel: LinkRelation) -> [Link] {
        return (readingOrder + resources + links).filter(byRel: rel)
    }
    
    /// Makes a copy of the `Manifest`, after modifying some of its properties.
    public func copy(
        context: [String]? = nil,
        metadata: Metadata? = nil,
        links: [Link]? = nil,
        readingOrder: [Link]? = nil,
        resources: [Link]? = nil,
        tableOfContents: [Link]? = nil,
        subcollections: [String: [PublicationCollection]]? = nil
    ) -> Manifest {
        Manifest(
            context: context ?? self.context,
            metadata: metadata ?? self.metadata,
            links: links ?? self.links,
            readingOrder: readingOrder ?? self.readingOrder,
            resources: resources ?? self.resources,
            tableOfContents: tableOfContents ?? self.tableOfContents,
            subcollections: subcollections ?? self.subcollections
        )
    }

}
