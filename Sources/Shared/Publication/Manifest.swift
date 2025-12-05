//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Holds the metadata of a Readium publication, as described in the Readium Web Publication
/// Manifest.
///
/// See. https://readium.org/webpub-manifest/
public struct Manifest: JSONEquatable, Hashable, Sendable {
    public var context: [String] // @context

    public var metadata: Metadata

    public var links: [Link]

    /// Identifies a list of resources in reading order for the publication.
    public var readingOrder: [Link]

    /// Identifies resources that are necessary for rendering the publication.
    public var resources: [Link]

    public var subcollections: [String: [PublicationCollection]]

    /// Identifies the collection that contains a table of contents.
    public var tableOfContents: [Link] {
        get { subcollections["toc"]?.first?.links ?? [] }
        set {
            if newValue.isEmpty {
                subcollections.removeValue(forKey: "toc")
            } else {
                subcollections["toc"] = [PublicationCollection(links: newValue)]
            }
        }
    }

    public init(
        context: [String] = [],
        metadata: Metadata = Metadata(),
        links: [Link] = [],
        readingOrder: [Link] = [],
        resources: [Link] = [],
        tableOfContents: [Link] = [],
        subcollections: [String: [PublicationCollection]] = [:]
    ) {
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
    public init(json: Any, warnings: WarningLogger? = nil) throws {
        guard var json = JSONDictionary(json) else {
            throw JSONError.parsing(Publication.self)
        }

        context = parseArray(json.pop("@context"), allowingSingle: true)
        metadata = try Metadata(json: json.pop("metadata"), warnings: warnings)

        links = [Link](json: json.pop("links"), warnings: warnings)

        // `readingOrder` used to be `spine`, so we parse `spine` as a fallback.
        readingOrder = [Link](json: json.pop("readingOrder") ?? json.pop("spine"), warnings: warnings)
            .filter { $0.mediaType != nil }
        resources = [Link](json: json.pop("resources"), warnings: warnings)
            .filter { $0.mediaType != nil }

        // Parses sub-collections from remaining JSON properties.
        subcollections = PublicationCollection.makeCollections(json: json.json, warnings: warnings)
    }

    /// The URL where this publication is served, computed from the `Link` with
    /// `self` relation.
    ///
    /// e.g. https://provider.com/pub1293/manifest.json gives https://provider.com/pub1293/
    public var baseURL: HTTPURL? {
        links.firstWithRel(.`self`)
            .takeIf { !$0.templated }
            .flatMap { HTTPURL(string: $0.href)?.removingLastPathSegment() }
    }

    public var json: JSONDictionary.Wrapped {
        makeJSON([
            "@context": encodeIfNotEmpty(context),
            "metadata": metadata.json,
            "links": links.json,
            "readingOrder": readingOrder.json,
            "resources": encodeIfNotEmpty(resources.json),
            "toc": encodeIfNotEmpty(tableOfContents.json),
        ], additional: PublicationCollection.serializeCollections(subcollections))
    }

    /// Returns whether this manifest conforms to the given Readium Web Publication Profile.
    public func conforms(to profile: Publication.Profile) -> Bool {
        guard !readingOrder.isEmpty else {
            return false
        }

        switch profile {
        case .audiobook:
            return readingOrder.allAreAudio
        case .divina:
            return readingOrder.allAreBitmap
        case .epub:
            // EPUB needs to be explicitly indicated in `conformsTo`, otherwise
            // it could be a regular Web Publication.
            return readingOrder.allAreHTML && metadata.conformsTo.contains(.epub)
        case .pdf:
            return readingOrder.allMatchingMediaType(.pdf)
        default:
            break
        }

        return metadata.conformsTo.contains(profile)
    }

    /// Finds the first Link having the given `href` in the manifest's links.
    public func linkWithHREF<T: URLConvertible>(_ href: T) -> Link? {
        func deepFind(href: AnyURL, in linkLists: [[Link]]) -> Link? {
            for links in linkLists {
                for link in links {
                    if link.url().normalized.string == href.string {
                        return link
                    } else if let child = deepFind(href: href, in: [link.alternates, link.children]) {
                        return child
                    }
                }
            }

            return nil
        }

        let href = href.anyURL.normalized
        let links = [readingOrder, resources, links]

        return deepFind(href: href, in: links)
            ?? deepFind(href: href.removingQuery().removingFragment(), in: links)
    }

    /// Finds the first link with the given relation in the manifest's links.
    public func linkWithRel(_ rel: LinkRelation) -> Link? {
        readingOrder.firstWithRel(rel)
            ?? resources.firstWithRel(rel)
            ?? links.firstWithRel(rel)
    }

    /// Finds all the links with the given relation in the manifest's links.
    public func linksWithRel(_ rel: LinkRelation) -> [Link] {
        (readingOrder + resources + links).filterByRel(rel)
    }

    /// Finds all the links matching the given predicate in the manifest's links.
    public func linksMatching(_ predicate: (Link) -> Bool) -> [Link] {
        (readingOrder + resources + links).filter(predicate)
    }
}
