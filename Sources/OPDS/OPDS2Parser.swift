//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
    /// - parameter url: The feed URL
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

        guard let jsonRoot = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            throw OPDS2ParserError.invalidJSON
        }

        guard let topLevelDict = jsonRoot as? [String: Any] else {
            throw OPDS2ParserError.invalidJSON
        }

        do {
            if topLevelDict["navigation"] == nil,
               topLevelDict["groups"] == nil,
               topLevelDict["publications"] == nil,
               topLevelDict["facets"] == nil
            {
                // Publication only
                parseData.publication = try Publication(json: topLevelDict)

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
    /// - parameter jsonDict: The json top level dictionary
    /// - Returns: The resulting Feed
    public static func parse(feedURL: URL, jsonDict: [String: Any]) throws -> Feed {
        guard let metadataDict = jsonDict["metadata"] as? [String: Any] else {
            throw OPDS2ParserError.metadataNotFound
        }

        guard let title = metadataDict["title"] as? String else {
            throw OPDS2ParserError.missingTitle
        }

        let feed = Feed(title: title)
        parseMetadata(opdsMetadata: feed.metadata, metadataDict: metadataDict)

        for (k, v) in jsonDict {
            switch k {
            case "@context":
                switch v {
                case let s as String:
                    feed.context.append(s)
                case let sArr as [String]:
                    feed.context.append(contentsOf: sArr)
                default:
                    continue
                }
            case "metadata": // Already handled above
                continue
            case "links":
                guard let links = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidLink
                }
                try parseLinks(feed: feed, feedURL: feedURL, links: links)
            case "facets":
                guard let facets = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidFacet
                }
                try parseFacets(feed: feed, feedURL: feedURL, facets: facets)
            case "publications":
                guard let publications = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidPublication
                }
                try parsePublications(feed: feed, feedURL: feedURL, publications: publications)
            case "navigation":
                guard let navLinks = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidNavigation
                }
                try parseNavigation(feed: feed, feedURL: feedURL, navLinks: navLinks)
            case "groups":
                guard let groups = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidGroup
                }
                try parseGroups(feed: feed, feedURL: feedURL, groups: groups)
            default:
                continue
            }
        }

        return feed
    }

    static func parseMetadata(opdsMetadata: OpdsMetadata, metadataDict: [String: Any]) {
        for (k, v) in metadataDict {
            switch k {
            case "title":
                if let title = v as? String {
                    opdsMetadata.title = title
                }
            case "numberOfItems":
                opdsMetadata.numberOfItem = v as? Int
            case "itemsPerPage":
                opdsMetadata.itemsPerPage = v as? Int
            case "modified":
                if let dateStr = v as? String {
                    opdsMetadata.modified = dateStr.dateFromISO8601
                }
            case "@type":
                opdsMetadata.rdfType = v as? String
            case "currentPage":
                opdsMetadata.currentPage = v as? Int
            default:
                continue
            }
        }
    }

    static func parseFacets(feed: Feed, feedURL: URL, facets: [[String: Any]]) throws {
        for facetDict in facets {
            guard let metadata = facetDict["metadata"] as? [String: Any] else {
                throw OPDS2ParserError.invalidFacet
            }
            guard let title = metadata["title"] as? String else {
                throw OPDS2ParserError.invalidFacet
            }
            let facet = Facet(title: title)
            parseMetadata(opdsMetadata: facet.metadata, metadataDict: metadata)
            for (k, v) in facetDict {
                if k == "links" {
                    guard let links = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidFacet
                    }
                    for linkDict in links {
                        var link = try Link(json: linkDict)
                        try link.normalizeHREFs(to: feedURL)
                        facet.links.append(link)
                    }
                }
            }
            feed.facets.append(facet)
        }
    }

    static func parseLinks(feed: Feed, feedURL: URL, links: [[String: Any]]) throws {
        for linkDict in links {
            var link = try Link(json: linkDict)
            try link.normalizeHREFs(to: feedURL)
            feed.links.append(link)
        }
    }

    static func parsePublications(feed: Feed, feedURL: URL, publications: [[String: Any]]) throws {
        for pubDict in publications {
            let pub = try Publication(json: pubDict)
            feed.publications.append(pub)
        }
    }

    static func parseNavigation(feed: Feed, feedURL: URL, navLinks: [[String: Any]]) throws {
        for navDict in navLinks {
            var link = try Link(json: navDict)
            try link.normalizeHREFs(to: feedURL)
            feed.navigation.append(link)
        }
    }

    static func parseGroups(feed: Feed, feedURL: URL, groups: [[String: Any]]) throws {
        for groupDict in groups {
            guard let metadata = groupDict["metadata"] as? [String: Any] else {
                throw OPDS2ParserError.invalidGroup
            }
            guard let title = metadata["title"] as? String else {
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
                    guard let links = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for linkDict in links {
                        var link = try Link(json: linkDict)
                        try link.normalizeHREFs(to: feedURL)
                        group.links.append(link)
                    }
                case "navigation":
                    guard let links = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for linkDict in links {
                        var link = try Link(json: linkDict)
                        try link.normalizeHREFs(to: feedURL)
                        group.navigation.append(link)
                    }
                case "publications":
                    guard let publications = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for pubDict in publications {
                        let publication = try Publication(json: pubDict)
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
