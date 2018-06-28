//
//  OPDS2Parser.swift
//  readium-opds
//
//  Created by Nikita Aizikovskyi on Jan-30-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation

import R2Shared
import PromiseKit

public enum OPDS2ParserError: Error {
    case invalidJSON
    case metadataNotFound
    case invalidLink
    case missingTitle
    case invalidFacet
    case invalidGroup
    case invalidPublication
    case invalidNavigation

    var localizedDescription: String {
        switch self {
        case .invalidJSON:
            return "OPDS 2 manifest is not valid JSON"
        case .metadataNotFound:
            return "Metadata not found"
        case .missingTitle:
            return "Missing title"
        case .invalidLink:
            return "Invalid link"
        case .invalidFacet:
            return "Invalid facet"
        case .invalidGroup:
            return "Invalid group"
        case .invalidPublication:
            return "Invalid publication"
        case .invalidNavigation:
            return "Invalid navigation"
        }
    }
}

public class OPDS2Parser {
  static var feedURL: URL?
    
  /// Parse an OPDS feed or publication.
  /// Feed can only be v2 (JSON).
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
              let parseData = try self.parse(jsonData: data, url: url, response: response!)
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
    /// Feed can only be v2 (JSON).
    /// - parameter jsonData: The json raw data
    /// - parameter url: The feed URL
    /// - parameter response: The response payload
    /// - Returns: The intermediate structure of type ParseData
    public static func parse(jsonData: Data, url: URL, response: URLResponse) throws -> ParseData {
        
        feedURL = url
        
        var parseData = ParseData(url: url, response: response, version: .OPDS2)
        
        guard let jsonRoot = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            throw OPDS2ParserError.invalidJSON
        }
        
        guard let topLevelDict = jsonRoot as? [String: Any] else {
            throw OPDS2ParserError.invalidJSON
        }
        
        if topLevelDict["navigation"] == nil
            && topLevelDict["groups"] == nil
            && topLevelDict["publications"] == nil
            && topLevelDict["facets"] == nil {
            
            // Publication only
            parseData.publication = try? Publication.parse(pubDict: topLevelDict)
            
        } else {
            
            // Feed
            parseData.feed = try? parse(jsonDict: topLevelDict)
            
        }

        return parseData
        
    }
    
    /// Parse an OPDS feed.
    /// Feed can only be v2 (JSON).
    /// - parameter jsonDict: The json top level dictionary
    /// - Returns: The resulting Feed
    public static func parse(jsonDict: [String: Any]) throws -> Feed {
        
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
                try parseLinks(feed: feed, links: links)
            case "facets":
                guard let facets = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidFacet
                }
                try parseFacets(feed: feed, facets: facets)
            case "publications":
                guard let publications = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidPublication
                }
                try parsePublications(feed: feed, publications: publications)
            case "navigation":
                guard let navLinks = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidNavigation
                }
                try parseNavigation(feed: feed, navLinks: navLinks)
            case "groups":
                guard let groups = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidGroup
                }
                try parseGroups(feed: feed, groups: groups)
            default:
                continue
            }
        }
        
        return feed
        
    }


    static internal func parseMetadata(opdsMetadata: OpdsMetadata, metadataDict: [String: Any]) {
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

    static internal func parseFacets(feed: Feed, facets: [[String: Any]]) throws {
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
                if (k == "links") {
                    guard let links = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidFacet
                    }
                    for linkDict in links {
                        let link = try Link.parse(linkDict: linkDict)
                        link.absoluteHref = URLHelper.getAbsolute(href: link.href, base: feedURL)
                        facet.links.append(link)
                    }
                }
            }
            feed.facets.append(facet)
        }
    }

    static internal func parseLinks(feed: Feed, links: [[String: Any]]) throws {
        for linkDict in links {
            let link = try Link.parse(linkDict: linkDict)
            link.absoluteHref = URLHelper.getAbsolute(href: link.href, base: feedURL)
            feed.links.append(link)
        }
    }

    static internal func parsePublications(feed: Feed, publications: [[String: Any]]) throws {
        for pubDict in publications {
            let pub = try Publication.parse(pubDict: pubDict)
            feed.publications.append(pub)
        }
    }

    static internal func parseNavigation(feed: Feed, navLinks: [[String: Any]]) throws {
        for navDict in navLinks {
            let link = try Link.parse(linkDict: navDict)
            link.absoluteHref = URLHelper.getAbsolute(href: link.href, base: feedURL)
            feed.navigation.append(link)
        }
    }

    static internal func parseGroups(feed: Feed, groups: [[String: Any]]) throws {
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
                        let link = try Link.parse(linkDict: linkDict)
                        link.absoluteHref = URLHelper.getAbsolute(href: link.href, base: feedURL)
                        group.links.append(link)
                    }
                case "navigation":
                    guard let links = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for linkDict in links {
                        let link = try Link.parse(linkDict: linkDict)
                        link.absoluteHref = URLHelper.getAbsolute(href: link.href, base: feedURL)
                        group.navigation.append(link)
                    }
                case "publications":
                    guard let publications = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for pubDict in publications {
                        let publication = try Publication.parse(pubDict: pubDict)
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
