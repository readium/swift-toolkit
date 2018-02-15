//
//  OPDSParser.swift
//  readium-opds
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import AEXML
import R2Shared
import PromiseKit

public enum OPDSParserError: Error {
    case missingTitle
    case documentNotFound
    
    var localizedDescription: String {
        switch self {
        case .missingTitle:
            return "The title is missing from the feed."
        case .documentNotFound:
            return "Document is not found"
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

public class OPDSParser {
    public static func parseURL(url: URL) -> Promise<Feed> {
        return Promise<Feed> {fulfill, reject in
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
                    let feed = try self.parse(xmlData: data)
                    fulfill(feed)
                }
                catch {
                    reject(error)
                }

            })
            task.resume()
        }
    }

    /// Parse an OPDS flux.
    ///
    /// - Parameter: The opds flux data.
    public static func parse(xmlData: Data) throws -> Feed {
        let document = try AEXMLDocument.init(xml: xmlData)
        let root = document.root

        guard let title = root["title"].value else {
            throw OPDSParserError.missingTitle
        }
        let feed = Feed.init(title: title)

        if let tmpDate = root["updated"].value,
            let date = tmpDate.dateFromISO8601
        {
            feed.metadata.modified = date
        }
        if let totalResults = root["TotalResults"].value {
            feed.metadata.numberOfItem = Int(totalResults)
        }
        if let itemsPerPage = root["ItemsPerPage"].value {
            feed.metadata.itemsPerPage = Int(itemsPerPage)
        }
        ///////
        guard let entries = root["entry"].all else {
            return feed
        }
        ////

        for entry in entries {
            var isNavigation = true
            let collectionLink = Link()

            if let links = entry["link"].all {
                for link in links {
                    if let rel = link.attributes["rel"] {
                        // Check is navigation or acquisition.
                        if rel.range(of: "http://opds-spec.org/acquisition") != nil {
                            isNavigation = false
                        }
                        // Check if there is a colelction.
                        if rel == "collection" || rel == "http://opds-spec.org/group" {
                            collectionLink.rel.append("collection")
                            collectionLink.href = link.attributes["href"]
                            collectionLink.title = link.attributes["title"]
                        }
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

                if let entryTitle = entry["title"].value {
                    newLink.title = entryTitle
                }
                if let _ = entry["link"].value {
                    if let rel = entry["link"].attributes["rel"] {
                        newLink.rel.append(rel)
                    }
                    newLink.typeLink = entry["link"].attributes["type"]
                    newLink.href = entry["link"].attributes["href"]
                }
                // Check collection link
                if collectionLink.href != nil {
                    addNavigationInGroup(feed, newLink, collectionLink)
                } else {
                    feed.navigation.append(newLink)
                }
            }
        }

        if let links = root["link"].all {
            for link in links {
                let newLink = Link()

                newLink.href = link.attributes["href"]
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
                if let facetGroupName = link.attributes["opds:facetGroup"],
                    newLink.rel.contains("http://opds-spec.org/facet")
                {
                    if let facetElementCountStr = link.attributes["thr:count"],
                        let facetElementCount = Int(facetElementCountStr) {
                        newLink.properties.numberOfItems = facetElementCount
                    }
                    addFacet(feed: feed, to: newLink, named: facetGroupName)
                } else {
                    feed.links.append(newLink)
                }
            }
        }
        
        return feed
    }

    public static func parseEntry(xmlData: Data) throws -> Publication {
        let document = try AEXMLDocument.init(xml: xmlData)
        let root = document.root
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
                    }
                }
                else if link.rel[0] == "search" {
                    guard let linkHref = link.href else {
                        reject(OPDSParserOpenSearchHelperError.searchLinkNotFound)
                        return
                    }
                    openSearchURL = URL(string: linkHref)
                }
            }

            guard let unwrappedURL = openSearchURL else {
                reject(OPDSParserOpenSearchHelperError.searchLinkNotFound)
                return
            }

            let task = URLSession.shared.dataTask(with: unwrappedURL, completionHandler: { (data, response, error) in
                guard error == nil else {
                    reject(error!)
                    return
                }
                guard let data = data else {
                    reject(OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                guard let document = try? AEXMLDocument.init(xml: data) else {
                    reject (OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                guard let urls = document.root["Url"].all else {
                    reject(OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                if urls.count == 0 {
                    reject(OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                    return
                }
                // The OpenSearch document may contain multiple Urls, and we need to find the closest matching one.
                // We match by mimetype and profile; if that fails, by mimetype; and if that fails, the first url is returned
                var typeAndProfileMatch: AEXMLElement? = nil
                var typeMatch: AEXMLElement? = nil
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
            })
            task.resume()
        }
    }

    static internal func parseEntry(entry: AEXMLElement) -> Publication {
        let publication = Publication()
        /// METADATA (publication) ----
        let metadata = Metadata()
        publication.metadata = metadata

        if let entryTitle = entry["title"].value {
            if metadata.multilangTitle == nil {
                metadata.multilangTitle = MultilangString()
            }
            metadata.multilangTitle?.singleString = entryTitle
        }

        if let identifier = entry["identifier"].value {
            metadata.identifier = identifier
        } else if let id = entry["id"].value {
            metadata.identifier = id
        }

        // Languages.
        if let languages = entry["dcterms:language"].all {
            metadata.languages = languages.map({ $0.string })
        }
        // Last modification date.
        if let tmpDate = entry["updated"].value,
            let date = tmpDate.dateFromISO8601
        {
            metadata.modified = date
        }
        // Publication date.
        if let tmpDate = entry["published"].value {
            metadata.publicationDate = tmpDate
        }

        // Rights.
        if let rights = entry["rights"].all {
            metadata.rights = rights.map({ $0.string }).joined(separator: " ")
        }
        // TODO SERIES -------------
        // Publisher
        if let publisher = entry["dcterms:publisher"].value {
            let contributor = Contributor()

            contributor.multilangName.singleString = publisher
            metadata.publishers.append(contributor)
        }
        // Categories.
        if let categories = entry["category"].all {
            for category in categories {
                let subject = Subject()

                subject.code = category.attributes["term"]
                subject.name = category.attributes["label"]
                subject.scheme = category.attributes["scheme"]
                metadata.subjects.append(subject)
            }
        }
        /// Contributors.
        // Author.
        if let authors = entry["author"].all {
            for author in authors {
                let contributor = Contributor()

                if let uri = author["uri"].value {
                    let link = Link()

                    link.href = uri
                    contributor.links.append(link)
                }
                contributor.multilangName.singleString = author["name"].value
                metadata.authors.append(contributor)
            }
        }
        // Description.
        if let content = entry["content"].value {
            metadata.description = content
        } else if let summary = entry["summary"].value {
            metadata.description = summary
        }
        // Links.
        if let links = entry["link"].all {
            for link in links {
                let newLink = Link()

                newLink.href = link.attributes["href"]
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
                if let indirectAcquisitions = link["opds:indirectAcquisition"].all,
                    !indirectAcquisitions.isEmpty
                {
                    newLink.properties.indirectAcquisition = parseIndirectAcquisition(children: indirectAcquisitions)
                }
                // Price.
                if let price = link["opds:price"].value,
                    let priceDouble = Double(price),
                    let currency = link["opds:price"].attributes["currencyCode"]
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
            for l in feed.links {
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
            for l in feed.links {
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
    static internal func parseIndirectAcquisition(children: [AEXMLElement]) -> [IndirectAcquisition] {
        var ret = [IndirectAcquisition]()

        for child in children {
            if let typeAcquisition = child.attributes["type"] {
                let newIndAcq = IndirectAcquisition(typeAcquisition: typeAcquisition)

                if let grandChildren = child["opds:indirectAcquisition"].all {
                    newIndAcq.child = parseIndirectAcquisition(children: grandChildren)
                }
                ret.append(newIndAcq)
            }
        }
        return ret
    }
}
