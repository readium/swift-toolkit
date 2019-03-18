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
    public var toc: [Link]
    public var otherCollections: [PublicationCollection]
    
    
    public init(context: [String] = [], metadata: Metadata, links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = [], toc: [Link] = [], otherCollections: [PublicationCollection] = []) {
        self.context = context
        self.metadata = metadata
        self.links = links
        self.readingOrder = readingOrder
        self.resources = resources
        self.toc = toc
        self.otherCollections = otherCollections
    }
    
    /// Parses a Readium Web Publication Manifest.
    /// https://readium.org/webpub-manifest/schema/publication.schema.json
    public init(json: Any) throws {
        guard var json = JSONDictionary(json) else {
            throw JSONParsingError.publication
        }
        
        self.context = parseArray(json.pop("@context"), allowingSingle: true)
        self.metadata = try Metadata(json: json.pop("metadata"))
        self.otherCollections = []
        self.links = [Link](json: json.pop("links"))
            .filter { !$0.rels.isEmpty }
        // `readerOrder` used to be `spine`, so we parse `spine` as a fallback.
        self.readingOrder = [Link](json: json.pop("readingOrder") ?? json.pop("spine"))
            .filter { $0.type != nil }
        self.resources = [Link](json: json.pop("resources"))
            .filter { $0.type != nil }
        self.toc = [Link](json: json.pop("toc"))

        // Parses sub-collections from remaining JSON properties.
        self.otherCollections = [PublicationCollection](json: json.json)
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "@context": encodeIfNotEmpty(context),
            "metadata": metadata.json,
            "links": links.json,
            "readingOrder": readingOrder.json,
            "resources": encodeIfNotEmpty(resources.json),
            "toc": encodeIfNotEmpty(toc.json),
        ], additional: otherCollections.json)
    }
    
    /// Returns the Manifest's data JSON representation.
    public var manifest: Data? {
        var options: JSONSerialization.WritingOptions = []
        if #available(iOS 11.0, *) {
            options.insert(.sortedKeys)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: options),
            var string = String(data: data, encoding: .utf8) else
        {
            return nil
        }
        
        // Unescapes slashes
        string = string.replacingOccurrences(of: "\\/", with: "/")
        return string.data(using: .utf8)
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
