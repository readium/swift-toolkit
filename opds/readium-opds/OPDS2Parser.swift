//
//  OPDS2Parser.swift
//  readium-opds
//
//  Created by Nikita Aizikovskyi on Jan-30-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation

import R2Shared

enum OPDS2ParserError: Error {
    case invalidJSON
    case metadataNotFound
    case invalidMetadata
    case missingTitle

    var localizedDescription: String {
        switch self {
        case .invalidJSON:
            return "OPDS 2 manifest is not valid JSON"
        case .metadataNotFound:
            return "Metadata not found"
        case .missingTitle:
            return "Missing title"
        case .invalidMetadata:
            return "Invalid metadata"
        }
    }
}

class OPDS2Parser {
    static func parse(jsonData: Data) throws -> Feed {
        guard let jsonRoot = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            throw OPDS2ParserError.invalidJSON
        }
        guard let topLevelDict = jsonRoot as? [String: Any] else {
            throw OPDS2ParserError.invalidJSON
        }
        guard let metadataDict = topLevelDict["metadata"] as? [String: Any] else {
            throw OPDS2ParserError.metadataNotFound

        }
        guard let title = metadataDict["title"] as? String else {
            throw OPDS2ParserError.missingTitle
        }
        let feed = Feed(title: title)

        // PARSE HERE

        return feed
    }

    static internal func parseMetadata(metadataDict: [String: Any], feed: Feed) throws -> OpdsMetadata {
        if let title = metadataDict["title"] as? String {
            feed.metadata.title = title
        }
        if let numberOfItems = metadataDict["numberOfItems"] as? String {
            feed.metadata.numberOfItem = Int(numberOfItems)
        }
        if let itemsPerPage = metadataDict["itemsPerPage"] as? String {
            feed.metadata.itemsPerPage = Int(itemsPerPage)
        }
        if let modified = metadataDict["modified"] as? String {
            feed.metadata.modified = modified.dateFromISO8601
        }
        if let modified = metadataDict["type"] as? String {
            feed.metadata.
        }
        return metadata
    }
}
