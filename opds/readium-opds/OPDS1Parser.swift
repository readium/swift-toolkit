//
//  OPDS1Parser.swift
//  readium-opds
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Fuzi
import R2Shared

public enum OPDS1ParserError: Error {
    // The title is missing from the feed.
    case missingTitle
    // Root is not found
    case rootNotFound
}

public enum OPDSParserOpenSearchHelperError: Error {
    // Search link not found in feed
    case searchLinkNotFound
    // OpenSearch document is invalid
    case searchDocumentIsInvalid
}

struct MimeTypeParameters {
    var type: String
    var parameters = [String: String]()
}

public class OPDS1Parser: Loggable {
    static var feedURL: URL?
    
    /// Parse an OPDS feed or publication.
    /// Feed can only be v1 (XML).
    /// - parameter url: The feed URL
    public static func parseURL(url: URL, completion: @escaping (ParseData?, Error?) -> Void) {
        feedURL = url
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let response = response else {
                completion(nil, error ?? OPDSParserError.documentNotFound)
                return
            }

            do {
                let parseData = try self.parse(xmlData: data, url: url, response: response)
                completion(parseData, nil)
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    /// Parse an OPDS feed or publication.
    /// Feed can only be v1 (XML).
    /// - parameter xmlData: The xml raw data
    /// - parameter url: The feed URL
    /// - parameter response: The response payload
    /// - Returns: The intermediate structure of type ParseData
    public static func parse(xmlData: Data, url: URL, response: URLResponse) throws -> ParseData {
        
        feedURL = url
        
        var parseData = ParseData(url: url, response: response, version: .OPDS1)
        
        let xmlDocument = try XMLDocument.init(data: xmlData)
        
        if xmlDocument.root?.tag == "feed" {
            // Feed
            parseData.feed = try? parse(document: xmlDocument)
        } else if xmlDocument.root?.tag == "entry" {
            // Publication only
            do {
                parseData.publication = try parseEntry(document: xmlDocument)
            } catch {
                log(.warning, "Failed to parse Publication at \(url)")
            }
        } else {
            throw OPDS1ParserError.rootNotFound
        }
        
        return parseData
        
    }
    
    /// Parse an OPDS feed.
    /// Feed can only be v1 (XML).
    /// - parameter document: The XMLDocument data
    /// - Returns: The resulting Feed
    public static func parse(document: Fuzi.XMLDocument) throws -> Feed {
        document.definePrefix("thr", forNamespace: "http://purl.org/syndication/thread/1.0")
        document.definePrefix("dcterms", forNamespace: "http://purl.org/dc/terms/")
        document.definePrefix("opds", forNamespace: "http://opds-spec.org/2010/catalog")
        
        guard let root = document.root else {
            throw OPDS1ParserError.rootNotFound
        }

        guard let title = root.firstChild(tag: "title")?.stringValue else {
            throw OPDS1ParserError.missingTitle
        }
        let feed = Feed.init(title: title)

        if let tmpDate = root.firstChild(tag: "updated")?.stringValue,
            let date = tmpDate.dateFromISO8601
        {
            feed.metadata.modified = date
        }
        if let totalResults = root.firstChild(tag: "TotalResults")?.stringValue {
            feed.metadata.numberOfItem = Int(totalResults)
        }
        if let itemsPerPage = root.firstChild(tag: "ItemsPerPage")?.stringValue {
            feed.metadata.itemsPerPage = Int(itemsPerPage)
        }

        for entry in root.children(tag: "entry") {
            var isNavigation = true
            var collectionLink: Link?

            for link in entry.children(tag: "link") {
                if let rel = link.attributes["rel"] {
                    // Check is navigation or acquisition.
                    if rel.range(of: "http://opds-spec.org/acquisition") != nil {
                        isNavigation = false
                    }
                    // Check if there is a collection.
                    if rel == "collection" || rel == "http://opds-spec.org/group",
                        let href = link.attributes["href"],
                        let absoluteHref = URLHelper.getAbsolute(href: href, base: feedURL)
                    {
                        collectionLink = Link(
                            href: absoluteHref,
                            title: link.attributes["title"],
                            rel: .collection
                        )
                    }
                }
            }

            if (!isNavigation) {
                if let publication = parseEntry(entry: entry) {
                    // Checking if this publication need to go into a group or in publications.
                    if let collectionLink = collectionLink {
                        addPublicationInGroup(feed, publication, collectionLink)
                    } else {
                        feed.publications.append(publication)
                    }
                }
                
            } else if let link = entry.firstChild(tag: "link"),
                let href = link.attr("href"),
                let absoluteHref = URLHelper.getAbsolute(href: href, base: feedURL)
            {
                var properties: [String: Any] = [:]
                if let facetElementCount = link.attr("count").map(Int.init) {
                    properties["numberOfItems"] = facetElementCount
                }
                
                let newLink = Link(
                    href: absoluteHref,
                    type: link.attr("type"),
                    title: entry.firstChild(tag: "title")?.stringValue,
                    rel: link.attr("rel").map { LinkRelation($0) },
                    properties: .init(properties)
                )

                // Check collection link
                if let collectionLink = collectionLink {
                    addNavigationInGroup(feed, newLink, collectionLink)
                } else {
                    feed.navigation.append(newLink)
                }
            }
        }

        for link in root.children(tag: "link") {
            guard let href = link.attributes["href"], let absoluteHref = URLHelper.getAbsolute(href: href, base: feedURL) else {
                continue
            }
            
            var rels: [LinkRelation] = []
            if let rel = link.attributes["rel"], !rel.isEmpty {
                rels.append(.init(rel))
            }
            var properties: [String: Any] = [:]
            
            let isFacet = rels.contains(.opdsFacet)
            if isFacet {
                // Active Facet Check
                if link.attr("activeFacet")?.lowercased() == "true" {
                    rels.append(.self)
                }
                
                if let facetElementCount = link.attr("count").map(Int.init) {
                    properties["numberOfItems"] = facetElementCount
                }
            }
            
            let newLink = Link(
                href: absoluteHref,
                type: link.attributes["type"],
                title: link.attributes["title"],
                rels: rels,
                properties: .init(properties)
            )

            if isFacet {
                if let facetGroupName = link.attributes["facetGroup"] {
                    addFacet(feed: feed, to: newLink, named: facetGroupName)
                }
            } else {
                feed.links.append(newLink)
            }
        }
        
        return feed
    }

    /// Parse an OPDS publication.
    /// Publication can only be v1 (XML).
    /// - parameter document: The XMLDocument data
    /// - Returns: The resulting Publication
    public static func parseEntry(document: Fuzi.XMLDocument) throws -> Publication? {
        guard let root = document.root else {
            throw OPDS1ParserError.rootNotFound
        }
        return parseEntry(entry: root)
    }

    /// Fetch an Open Search template from an OPDS feed.
    /// - parameter feed: The OPDS feed
    public static func fetchOpenSearchTemplate(feed: Feed, completion: @escaping (String?, Error?) -> Void) {
        guard let openSearchHref = feed.links.first(withRel: .search)?.href,
            let openSearchURL = URL(string: openSearchHref) else
        {
            completion(nil, OPDSParserOpenSearchHelperError.searchLinkNotFound)
            return
        }

        URLSession.shared.dataTask(with: openSearchURL) { data, _, error in
            guard let data = data else {
                completion(nil, error ?? OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }
            guard let document = try? XMLDocument.init(data: data) else {
                completion(nil, OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }
            guard let urls = document.root?.children(tag: "Url") else {
                completion(nil, OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }
            if urls.count == 0 {
                completion(nil, OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }
            // The OpenSearch document may contain multiple Urls, and we need to find the closest matching one.
            // We match by mimetype and profile; if that fails, by mimetype; and if that fails, the first url is returned
            var typeAndProfileMatch: Fuzi.XMLElement? = nil
            var typeMatch: Fuzi.XMLElement? = nil
            if let selfMimeType = feed.links.first(withRel: .self)?.type {
                let selfMimeParams = parseMimeType(mimeTypeString: selfMimeType)
                for url in urls {
                    guard let urlMimeType = url.attributes["type"] else {
                        continue
                    }
                    let otherMimeParams = parseMimeType(mimeTypeString: urlMimeType)
                    if selfMimeParams.type == otherMimeParams.type {
                        if typeMatch == nil {
                            typeMatch = url
                        }
                        if selfMimeParams.parameters["profile"] == otherMimeParams.parameters["profile"] {
                            typeAndProfileMatch = url
                            break
                        }
                    }
                }
            }
            let match = typeAndProfileMatch ?? (typeMatch ?? urls[0])
            guard let template = match.attributes["template"] else {
                completion(nil, OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }

            completion(template, nil)
        }.resume()
    }
    
    static func parseMimeType(mimeTypeString: String) -> MimeTypeParameters {
        let substrings = mimeTypeString.split(separator: ";")
        let type = String(substrings[0]).trimmingCharacters(in: .whitespaces)
        var params = [String: String]()
        for defn in substrings.dropFirst() {
            let halves = defn.split(separator: "=")
            let paramName = String(halves[0]).trimmingCharacters(in: .whitespaces)
            let paramValue = String(halves[1]).trimmingCharacters(in: .whitespaces)
            params[paramName] = paramValue
        }
        return MimeTypeParameters(type: type, parameters: params)
    }

    static func parseEntry(entry: Fuzi.XMLElement) -> Publication? {
        
        // Shortcuts to get tag(s)' string value.
        func tag(_ name: String) -> String? {
            return entry.firstChild(tag: name)?.stringValue
        }
        func tags(_ name: String) -> [String] {
            return entry.children(tag: name).map { $0.stringValue }
        }
        
        guard let title = tag("title") else {
            return nil
        }
        
        let authors: [Contributor] = entry.children(tag: "author").compactMap { author in
            guard let name = author.firstChild(tag: "name")?.stringValue else {
                return nil
            }
            return Contributor(
                name: name,
                identifier: author.firstChild(tag: "uri")?.stringValue
            )
        }
        
        let subjects: [Subject] = entry.children(tag: "category").compactMap { category in
            guard let name = category.attributes["label"] else {
                return nil
            }
            return Subject(
                name: name,
                scheme: category.attributes["scheme"],
                code: category.attributes["term"]
            )
        }

        let metadata = Metadata(
            identifier: tag("identifier") ?? tag("id"),
            title: title,
            modified: tag("updated")?.dateFromISO8601,
            published: tag("published")?.dateFromISO8601,
            languages: tags("language"),
            subjects: subjects,
            authors: authors,
            publishers: tags("publisher").map { Contributor(name: $0) },
            description: tag("content") ?? tag("summary"),
            otherMetadata: [
                "rights": tags("rights").joined(separator: " "),
            ]
        )

        // Links.
        var images: [Link] = []
        var links: [Link] = []
        for linkElement in entry.children(tag: "link") {
            guard let href = linkElement.attributes["href"], let absoluteHref = URLHelper.getAbsolute(href: href, base: feedURL) else {
                continue
            }
            
            var properties: [String: Any] = [:]
            if let price = parsePrice(link: linkElement)?.json, !price.isEmpty {
                properties["price"] = price
            }
            let indirectAcquisition = parseIndirectAcquisition(children: linkElement.children(tag: "indirectAcquisition")).json
            if !indirectAcquisition.isEmpty {
                properties["indirectAcquisition"] = indirectAcquisition
            }
            
            let link = Link(
                href: absoluteHref,
                type: linkElement.attributes["type"],
                title: linkElement.attributes["title"],
                rel: linkElement.attributes["rel"].map { LinkRelation($0) },
                properties: .init(properties)
            )

            let rels = link.rels

            if rels.contains("collection") || rels.contains("http://opds-spec.org/group") {
                // no-op
            } else if rels.contains("http://opds-spec.org/image") || rels.contains("http://opds-spec.org/image-thumbnail") {
                images.append(link)
            } else {
                links.append(link)
            }
        }

        return Publication(
            manifest: Manifest(
                metadata: metadata,
                links: links,
                subcollections: [
                    "images": [PublicationCollection(links: images)]
                ]
            )
        )
    }

    static func addFacet(feed: Feed, to link: Link, named title: String) {
        for facet in feed.facets {
            if facet.metadata.title == title {
                facet.links.append(link)
                return
            }
        }
        let newFacet = Facet(title: title)

        newFacet.links.append(link)
        feed.facets.append(newFacet)
    }

    static func addPublicationInGroup(_ feed: Feed,
                                               _ publication: Publication,
                                               _ collectionLink: Link)
    {
        for group in feed.groups {
            for l in group.links {
                if l.href == collectionLink.href {
                    group.publications.append(publication)
                    return
                }
            }
        }
        if let title = collectionLink.title {
            let newGroup = Group.init(title: title)
            let selfLink = Link(
                href: collectionLink.href,
                title: collectionLink.title,
                rel: .self
            )
            newGroup.links.append(selfLink)
            newGroup.publications.append(publication)
            feed.groups.append(newGroup)
        }
    }

    static func addNavigationInGroup(_ feed: Feed,
                                              _ link: Link,
                                              _ collectionLink: Link)
    {
        for group in feed.groups {
            for l in group.links {
                if l.href == collectionLink.href {
                    group.navigation.append(link)
                    return
                }
            }
        }
        if let title = collectionLink.title {
            let newGroup = Group.init(title: title)
            let selfLink = Link(
                href: collectionLink.href,
                title: collectionLink.title,
                rel: .self
            )
            newGroup.links.append(selfLink)
            newGroup.navigation.append(link)
            feed.groups.append(newGroup)
        }
    }
    
    static func parseIndirectAcquisition(children: [Fuzi.XMLElement]) -> [OPDSAcquisition] {
        return children.compactMap { child in
            guard let type = child.attributes["type"] else {
                return nil
            }
            var acquisition = OPDSAcquisition(type: type)
            let grandChildren = child.children(tag: "indirectAcquisition")
            if grandChildren.count > 0 {
                acquisition.children = parseIndirectAcquisition(children: grandChildren)
            }
            return acquisition
        }
    }
    
    static func parsePrice(link: Fuzi.XMLElement) -> OPDSPrice? {
        guard let price = link.firstChild(tag: "price")?.stringValue,
            let value = Double(price),
            let currency = link.firstChild(tag: "price")?.attr("currencycode") else
        {
            return nil
        }
        
        return OPDSPrice(currency: currency, value: value)
    }
    
}
