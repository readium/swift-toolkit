//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public enum OPDS2ParserError: Error {
    case invalidJSON
    case metadataNotFound
    case invalidLink
    case missingTitle
    case invalidFacet
    case invalidGroup
    case invalidPublication
    case invalidNavigation
}

public class OPDS2Parser: Loggable {
    /// Parse an OPDS feed or publication.
    /// Feed can only be v2 (JSON).
    /// - Parameters:
    ///   - url: The feed URL.
    ///   - completion: A closure called when the parsing is complete, returning the
    ///     parsed `ParseData` on success, or an `Error` if the operation failed.
    public static func parseURL(url: URL, completion: @escaping (ParseData?, Error?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let response = response else {
                completion(nil, error ?? OPDSParserError.documentNotFound)
                return
            }

            do {
                let parseData = try self.parse(jsonData: data, url: url, response: response)
                completion(parseData, nil)
            } catch {
                completion(nil, error)
            }
        }.resume()
    }

    /// Parse an OPDS feed or publication.
    /// Feed can only be v2 (JSON).
    /// - parameter jsonData: The json raw data
    /// - parameter url: The feed URL
    /// - parameter response: The response payload
    /// - Returns: The intermediate structure of type ParseData
    public static func parse(jsonData: Data, url: URL, response: URLResponse) throws -> ParseData {
        var parseData = ParseData(url: url, response: response, version: .OPDS2)

        guard let jsonRoot = try? JSONValue(jsonData: jsonData),
              let topLevelDict = jsonRoot.object
        else {
            throw OPDS2ParserError.invalidJSON
        }

        do {
            if topLevelDict["navigation"] == nil,
               topLevelDict["groups"] == nil,
               topLevelDict["publications"] == nil,
               topLevelDict["facets"] == nil
            {
                // Publication only
                parseData.publication = try Publication(json: jsonRoot)
            } else {
                // Feed
                parseData.feed = try parse(feedURL: url, jsonDict: topLevelDict)
            }
        } catch {
            log(.warning, error)
        }

        return parseData
    }

    /// Parse an OPDS feed.
    /// Feed can only be v2 (JSON).
    /// - Parameters:
    ///   - feedURL: The URL of the feed being parsed, used to resolve relative links.
    ///   - jsonDict: The JSON top-level dictionary.
    /// - Returns: The resulting `Feed` object.
    /// - Throws: An error if the JSON structure is invalid or missing required OPDS fields.
    public static func parse(feedURL: URL, jsonDict: [String: JSONValue]) throws -> Feed {
        guard let metadataDict = jsonDict["metadata"]?.object else {
            throw OPDS2ParserError.metadataNotFound
        }

        guard let title = metadataDict["title"]?.string else {
            throw OPDS2ParserError.missingTitle
        }

        let feed = Feed(title: title)
        parseMetadata(opdsMetadata: feed.metadata, metadataDict: metadataDict)

        for (k, v) in jsonDict {
            switch k {
            case "@context":
                if let s = v.string {
                    feed.context.append(s)
                } else if let sArr = v.array {
                    feed.context.append(contentsOf: sArr.compactMap(\.string))
                }
            case "metadata": // Already handled above
                continue
            case "links":
                guard let links = v.array else {
                    throw OPDS2ParserError.invalidLink
                }
                try parseLinks(feed: feed, feedURL: feedURL, links: links)
            case "facets":
                guard let facets = v.array else {
                    throw OPDS2ParserError.invalidFacet
                }
                try parseFacets(feed: feed, feedURL: feedURL, facets: facets)
            case "publications":
                guard let publications = v.array else {
                    throw OPDS2ParserError.invalidPublication
                }
                try parsePublications(feed: feed, feedURL: feedURL, publications: publications)
            case "navigation":
                guard let navLinks = v.array else {
                    throw OPDS2ParserError.invalidNavigation
                }
                try parseNavigation(feed: feed, feedURL: feedURL, navLinks: navLinks)
            case "groups":
                guard let groups = v.array else {
                    throw OPDS2ParserError.invalidGroup
                }
                try parseGroups(feed: feed, feedURL: feedURL, groups: groups)
            default:
                continue
            }
        }

        return feed
    }

    static func parseMetadata(opdsMetadata: OpdsMetadata, metadataDict: [String: JSONValue]) {
        for (k, v) in metadataDict {
            switch k {
            case "title":
                if let title = v.string {
                    opdsMetadata.title = title
                }
            case "numberOfItems":
                opdsMetadata.numberOfItem = v.integer
            case "itemsPerPage":
                opdsMetadata.itemsPerPage = v.integer
            case "modified":
                if let dateStr = v.string {
                    opdsMetadata.modified = dateStr.dateFromISO8601
                }
            case "@type":
                opdsMetadata.rdfType = v.string
            case "currentPage":
                opdsMetadata.currentPage = v.integer
            default:
                continue
            }
        }
    }

    static func parseFacets(feed: Feed, feedURL: URL, facets: [JSONValue]) throws {
        for facetValue in facets {
            guard let facetDict = facetValue.object else { continue }
            guard let metadata = facetDict["metadata"]?.object else {
                throw OPDS2ParserError.invalidFacet
            }
            guard let title = metadata["title"]?.string else {
                throw OPDS2ParserError.invalidFacet
            }

            let facet = Facet(title: title)
            parseMetadata(opdsMetadata: facet.metadata, metadataDict: metadata)

            for (k, v) in facetDict {
                if k == "links" {
                    guard let links = v.array else {
                        throw OPDS2ParserError.invalidFacet
                    }
                    for linkValue in links {
                        if var link = try Link(json: linkValue) {
                            try link.normalizeHREFs(to: feedURL)
                            facet.links.append(link)
                        }
                    }
                }
            }
            feed.facets.append(facet)
        }
    }

    static func parseLinks(feed: Feed, feedURL: URL, links: [JSONValue]) throws {
        for linkValue in links {
            if var link = try Link(json: linkValue) {
                try link.normalizeHREFs(to: feedURL)
                feed.links.append(link)
            }
        }
    }

    static func parsePublications(feed: Feed, feedURL: URL, publications: [JSONValue]) throws {
        for pubValue in publications {
            let pub = try Publication(json: pubValue)
            feed.publications.append(pub)
        }
    }

    static func parseNavigation(feed: Feed, feedURL: URL, navLinks: [JSONValue]) throws {
        for navValue in navLinks {
            if var link = try Link(json: navValue) {
                try link.normalizeHREFs(to: feedURL)
                feed.navigation.append(link)
            }
        }
    }

    static func parseGroups(feed: Feed, feedURL: URL, groups: [JSONValue]) throws {
        for groupValue in groups {
            guard let groupDict = groupValue.object else { continue }
            guard let metadata = groupDict["metadata"]?.object else {
                throw OPDS2ParserError.invalidGroup
            }
            guard let title = metadata["title"]?.string else {
                throw OPDS2ParserError.invalidGroup
            }

            let group = Group(title: title)
            parseMetadata(opdsMetadata: group.metadata, metadataDict: metadata)

            for (k, v) in groupDict {
                switch k {
                case "metadata":
                    // Already handled above
                    continue
                case "links":
                    guard let links = v.array else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for linkValue in links {
                        if var link = try Link(json: linkValue) {
                            try link.normalizeHREFs(to: feedURL)
                            group.links.append(link)
                        }
                    }
                case "navigation":
                    guard let links = v.array else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for linkValue in links {
                        if var link = try Link(json: linkValue) {
                            try link.normalizeHREFs(to: feedURL)
                            group.navigation.append(link)
                        }
                    }
                case "publications":
                    guard let publications = v.array else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for pubValue in publications {
                        let publication = try Publication(json: pubValue)
                        group.publications.append(publication)
                    }
                default:
                    continue
                }
            }
            feed.groups.append(group)
        }
    }
}

private func hrefNormalizer(_ baseURL: URL?) -> (String) -> (String) {
    { href in URLHelper.getAbsolute(href: href, base: baseURL) ?? href }
}
