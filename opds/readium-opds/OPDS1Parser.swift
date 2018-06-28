//
//  OPDS1Parser.swift
//  readium-opds
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Fuzi
import R2Shared
import PromiseKit

public enum OPDS1ParserError: Error {
    case missingTitle
    case rootNotFound
    
    var localizedDescription: String {
        switch self {
        case .missingTitle:
            return "The title is missing from the feed."
        case .rootNotFound:
            return "Root is not found"
        }
    }
}

public enum OPDSParserOpenSearchHelperError: Error {
    case searchLinkNotFound
    case searchDocumentIsInvalid
//    case missingTemplateForFeedType

    var localizedDescription: String {
        switch self {
        case .searchLinkNotFound:
            return "Search link not found in feed"
        case .searchDocumentIsInvalid:
            return "OpenSearch document is invalid"
//        case .missingTemplateForFeedType:
//            return "Missing search template for feed type"
        }
    }
}

struct MimeTypeParameters {
    var type: String
    var parameters = [String: String]()
}

public class OPDS1Parser {
    static var feedURL: URL?
    
    /// Parse an OPDS feed or publication.
    /// Feed can only be v1 (XML).
    /// - parameter url: The feed URL
    /// - Returns: A promise with the intermediate structure of type ParseData
    public static func parseURL(url: URL) -> Promise<ParseData> {
        feedURL = url
        
        return Promise<ParseData> {fulfill, reject in
            let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                guard error == nil else {
                    reject(error!)
                    return
                }
                guard let data = data else {
                    reject(OPDSParserError.documentNotFound)
                    return
                }
                do {
                    let parseData = try self.parse(xmlData: data, url: url, response: response!)
                    fulfill(parseData)
                }
                catch {
                    reject(error)
                }

            })
            task.resume()
        }
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
            parseData.publication = try? parseEntry(document: xmlDocument)
        } else {
            throw OPDS1ParserError.rootNotFound
        }
        
        return parseData
        
    }
    
    /// Parse an OPDS feed.
    /// Feed can only be v1 (XML).
    /// - parameter document: The XMLDocument data
    /// - Returns: The resulting Feed
    public static func parse(document: XMLDocument) throws -> Feed {
        document.definePrefix("thr", defaultNamespace: "http://purl.org/syndication/thread/1.0")
        document.definePrefix("dcterms", defaultNamespace: "http://purl.org/dc/terms/")
        document.definePrefix("opds", defaultNamespace: "http://opds-spec.org/2010/catalog")
        
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
            let collectionLink = Link()

            for link in entry.children(tag: "link") {
                if let rel = link.attributes["rel"] {
                    // Check is navigation or acquisition.
                    if rel.range(of: "http://opds-spec.org/acquisition") != nil {
                        isNavigation = false
                    }
                    // Check if there is a colelction.
                    if rel == "collection" || rel == "http://opds-spec.org/group" {
                        collectionLink.rel.append("collection")
                        collectionLink.href = link.attributes["href"]
                        collectionLink.absoluteHref = URLHelper.getAbsolute(href: link.attributes["href"], base: feedURL)
                        collectionLink.title = link.attributes["title"]
                    }
                }
            }

            if (!isNavigation) {
                let publication = parseEntry(entry: entry)

                // Checking if this publication need to go into a group or in publications.
                if collectionLink.href != nil {
                    addPublicationInGroup(feed, publication, collectionLink)
                } else {
                    feed.publications.append(publication)
                }
            } else {
                let newLink = Link()

                if let entryTitle = entry.firstChild(tag: "title")?.stringValue {
                    newLink.title = entryTitle
                }
                
                if let rel = entry.firstChild(tag: "link")?.attr("rel") {
                    newLink.rel.append(rel)
                }
                
                if let facetElementCountStr = entry.firstChild(tag: "link")?.attr("count"),
                    let facetElementCount = Int(facetElementCountStr) {
                    newLink.properties.numberOfItems = facetElementCount
                }
                
                newLink.typeLink = entry.firstChild(tag: "link")?.attr("type")
                newLink.href = entry.firstChild(tag: "link")?.attr("href")
                newLink.absoluteHref = URLHelper.getAbsolute(href: entry.firstChild(tag: "link")?.attr("href"), base: feedURL)
                
                // Check collection link
                if collectionLink.href != nil {
                    addNavigationInGroup(feed, newLink, collectionLink)
                } else {
                    feed.navigation.append(newLink)
                }
            }
        }

        for link in root.children(tag: "link") {
            let newLink = Link()

            newLink.href = link.attributes["href"]
            newLink.absoluteHref = URLHelper.getAbsolute(href: link.attributes["href"], base: feedURL)
            newLink.title = link.attributes["title"]
            newLink.typeLink = link.attributes["type"]
            if let rel = link.attributes["rel"] {
                newLink.rel.append(rel)
            }
            //                    if let rels = link.attributes["rel"]?.split(separator: " ") {
            //                        for rel in rels {
            //                            newLink.rel.append(rel)
            //                        }
            //                    }
            if let facetGroupName = link.attributes["facetGroup"],
                newLink.rel.contains("http://opds-spec.org/facet")
            {
                if let facetElementCountStr = link.attributes["count"],
                    let facetElementCount = Int(facetElementCountStr) {
                    newLink.properties.numberOfItems = facetElementCount
                }
                addFacet(feed: feed, to: newLink, named: facetGroupName)
            } else {
                feed.links.append(newLink)
            }
        }
        
        return feed
    }

    public static func parseEntry(document: XMLDocument) throws -> Publication {
        guard let root = document.root else {
            throw OPDS1ParserError.rootNotFound
        }
        return parseEntry(entry: root)
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

    public static func fetchOpenSearchTemplate(feed: Feed) -> Promise<String> {
        return Promise<String> { fulfill, reject in
            var openSearchURL: URL? = nil
            var selfMimeType: String? = nil

            for link in feed.links {
                if link.rel[0] == "self" {
                    if let linkType = link.typeLink {
                        selfMimeType = linkType
                        if openSearchURL != nil {
                            break
                        }
                    }
                }
                else if link.rel[0] == "search" {
                    guard let linkHref = link.href else {
                        reject(OPDSParserOpenSearchHelperError.searchLinkNotFound)
                        return
                    }
                    openSearchURL = URL(string: linkHref)
                    if selfMimeType != nil {
                        break
                    }
                }
            }

            guard let unwrappedURL = openSearchURL else {
                reject(OPDSParserOpenSearchHelperError.searchLinkNotFound)
                return
            }

            URLSession.shared.dataTask(with: unwrappedURL, completionHandler: { (data, response, error) in
                guard error == nil else {
                    reject(error!)
                    return
                }
                guard let data = data else {
                    reject(OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                guard let document = try? XMLDocument.init(data: data) else {
                    reject (OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                guard let urls = document.root?.children(tag: "Url") else {
                    reject(OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                if urls.count == 0 {
                    reject(OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                // The OpenSearch document may contain multiple Urls, and we need to find the closest matching one.
                // We match by mimetype and profile; if that fails, by mimetype; and if that fails, the first url is returned
                var typeAndProfileMatch: XMLElement? = nil
                var typeMatch: XMLElement? = nil
                if let unwrappedSelfMimeType = selfMimeType {
                    let selfMimeParams = parseMimeType(mimeTypeString: unwrappedSelfMimeType)
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
                    reject(OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                fulfill(template)
                return
            }).resume()
        }
    }

    static internal func parseEntry(entry: XMLElement) -> Publication {
        let publication = Publication()
        /// METADATA (publication) ----
        let metadata = Metadata()
        publication.metadata = metadata

        if let entryTitle = entry.firstChild(tag: "title")?.stringValue {
            if metadata.multilangTitle == nil {
                metadata.multilangTitle = MultilangString()
            }
            metadata.multilangTitle?.singleString = entryTitle
        }

        if let identifier = entry.firstChild(tag: "identifier")?.stringValue {
            metadata.identifier = identifier
        } else if let id = entry.firstChild(tag: "id")?.stringValue {
            metadata.identifier = id
        }

        // Languages.
        let languages = entry.children(tag: "language")
        if languages.count > 0 {
            metadata.languages = languages.map({ $0.stringValue })
        }
        // Last modification date.
        if let tmpDate = entry.firstChild(tag: "updated")?.stringValue,
            let date = tmpDate.dateFromISO8601
        {
            metadata.modified = date
        }
        // Publication date.
        if let tmpDate = entry.firstChild(tag: "published")?.stringValue {
            metadata.publicationDate = tmpDate
        }

        // Rights.
        let rights = entry.children(tag: "rights")
        if rights.count > 0 {
            metadata.rights = rights.map({ $0.stringValue }).joined(separator: " ")
        }
        // TODO SERIES -------------
        // Publisher
        if let publisher = entry.firstChild(tag: "publisher")?.stringValue {
            let contributor = Contributor()

            contributor.multilangName.singleString = publisher
            metadata.publishers.append(contributor)
        }
        // Categories.
        for category in entry.children(tag: "category") {
            let subject = Subject()

            subject.code = category.attributes["term"]
            subject.name = category.attributes["label"]
            subject.scheme = category.attributes["scheme"]
            metadata.subjects.append(subject)
        }
        /// Contributors.
        // Author.
        for author in entry.children(tag: "author") {
            let contributor = Contributor()

            if let uri = author.firstChild(tag: "uri")?.stringValue {
                let link = Link()
                link.href = uri
                link.absoluteHref = URLHelper.getAbsolute(href: uri, base: feedURL)
                contributor.links.append(link)
            }
            
            contributor.multilangName.singleString = author.firstChild(tag: "name")?.stringValue
            metadata.authors.append(contributor)
        }
        // Description.
        if let content = entry.firstChild(tag: "content")?.stringValue {
            metadata.description = content
        } else if let summary = entry.firstChild(tag: "summary")?.stringValue {
            metadata.description = summary
        }
        // Links.
        for link in entry.children(tag: "link") {
            let newLink = Link()

            newLink.href = link.attributes["href"]
            newLink.absoluteHref = URLHelper.getAbsolute(href: link.attributes["href"], base: feedURL)
            newLink.title = link.attributes["title"]
            newLink.typeLink = link.attributes["type"]
            if let rel = link.attributes["rel"] {
                newLink.rel.append(rel)
            }
            //                            if let rels = link.attributes["rel"]?.split(separator: " ") {
            //                                for rel in rels {
            //                                    newLink.rel.append(rel)
            //                                }
            //                            }
            // Indirect acquisition check. (Recursive)
            let indirectAcquisitions = link.children(tag: "indirectAcquisition")
            if !indirectAcquisitions.isEmpty {
                newLink.properties.indirectAcquisition = parseIndirectAcquisition(children: indirectAcquisitions)
            }
            // Price.
            if let price = link.firstChild(tag: "price")?.stringValue,
                let priceDouble = Double(price),
                let currency = link.firstChild(tag: "price")?.attr("currencyCode")
            {
                let newPrice = Price(currency: currency, value: priceDouble)

                newLink.properties.price = newPrice
            }
            if let rel = link.attributes["rel"] {
                if rel == "collection" || rel == "http://opds-spec.org/group" {
                } else if rel == "http://opds-spec.org/image" || rel == "http://opds-spec.org/image-thumbnail" {
                    publication.images.append(newLink)
                } else {
                    publication.links.append(newLink)
                }
            }
        }

        return publication
    }

    static internal func addFacet(feed: Feed, to link: Link, named title: String) {
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

    static internal func addPublicationInGroup(_ feed: Feed,
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
            let selfLink = Link()

            selfLink.href = collectionLink.href
            selfLink.absoluteHref = URLHelper.getAbsolute(href: selfLink.href, base: feedURL)
            selfLink.title = collectionLink.title
            selfLink.rel.append("self")
            newGroup.links.append(selfLink)
            //
            newGroup.publications.append(publication)
            //
            feed.groups.append(newGroup)
        }
    }

    static internal func addNavigationInGroup(_ feed: Feed,
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
            let selfLink = Link()

            selfLink.href = collectionLink.href
            selfLink.absoluteHref = URLHelper.getAbsolute(href: collectionLink.href, base: feedURL)
            selfLink.title = collectionLink.title
            selfLink.rel.append("self")
            newGroup.links.append(selfLink)
            //
            newGroup.navigation.append(link)
            //
            feed.groups.append(newGroup)
        }
    }

    /// <#Description#>
    ///
    /// - Parameter children: <#children description#>
    /// - Returns: <#return value description#>
    static internal func parseIndirectAcquisition(children: [XMLElement]) -> [IndirectAcquisition] {
        var ret = [IndirectAcquisition]()

        for child in children {
            if let typeAcquisition = child.attributes["type"] {
                let newIndAcq = IndirectAcquisition(typeAcquisition: typeAcquisition)

                let grandChildren = child.children(tag: "indirectAcquisition")
                if grandChildren.count > 0 {
                    newIndAcq.child = parseIndirectAcquisition(children: grandChildren)
                }
                ret.append(newIndAcq)
            }
        }
        return ret
    }
}
