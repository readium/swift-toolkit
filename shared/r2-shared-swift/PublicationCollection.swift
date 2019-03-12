//
//  PublicationCollection.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

/// Collection construct used for collection/serie metadata
public class PublicationCollection {
    /// The name of the colection.
    public var name: String
    ///
    public var sortAs: String?
    /// An unambiguous reference to this contributor.
    public var identifier: String?
    /// Indicate the position of the book in the collection.
    public var position: Double?
    /// Elements of the collection.
    public var links = [Link]()
    
    public init(name: String) {
        self.name = name
    }
}

// MARK: - Parsing related errors
public enum PublicationCollectionError: Error {
    case invalidCollection
    
    var localizedDescription: String {
        switch self {
        case .invalidCollection:
            return "Invalid collection"
        }
    }
}

// MARK: - Parsing related methods
extension PublicationCollection {
    
    static public func parse(_ collectionDict: [String: Any]) throws -> PublicationCollection {
        guard let name = collectionDict["name"] as? String else {
            throw PublicationCollectionError.invalidCollection
        }
        let c = PublicationCollection(name: name)
        for (k, v) in collectionDict {
            switch k {
            case "name": // Already handled above
                continue
            case "sort_as":
                c.sortAs = v as? String
            case "identifier":
                c.identifier = v as? String
            case "position":
                c.position = v as? Double
            case "links":
                guard let links = v as? [[String: Any]] else {
                    throw PublicationCollectionError.invalidCollection
                }
                for link in links {
                    c.links.append(try Link.parse(linkDict: link))
                }
            default:
                continue
            }
        }
        return c
    }
    
}
