//
//  Contributors.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// Generated from <dc:contributor>.
/// An entity responsible for making contributions to the resource.
public class Contributor {
    public var multilangName = MultilangString()
    /// The name of the contributor.
    public var name: String? {
        get {
            return multilangName.singleString
        }
    }
    public var sortAs: String?
    /// An unambiguous reference to this contributor.
    public var identifier: String?
    /// The role of the contributor in the publication making.
    public var roles = [String]()
    /// Used to retrieve similar publications for the given contributor.
    public var links = [Link]()

    public init() {}

    public required init?(map: Map) {}

}
extension Contributor: Mappable {
    /// JSON Serialisation function.
    public func mapping(map: Map) {
        // If multiString is not empty, then serialize it.
        if !multilangName.multiString.isEmpty {
            multilangName.multiString <- map["name"]
        } else {
            var nameForSinglestring = multilangName.singleString ?? ""

            nameForSinglestring <- map["name"]
        }
        sortAs <- map["sortAs", ignoreNil: true]
        identifier <- map["identifier", ignoreNil: true]
        if !roles.isEmpty {
            roles <- map["roles", ignoreNil: true]
        }
    }
}

// MARK: - Parsing related errors
public enum ContributorError: Error {
    case invalidContributor
    
    var localizedDescription: String {
        switch self {
        case .invalidContributor:
            return "Invalid contributor"
        }
    }
}

// MARK: - Parsing related methods
extension Contributor {
    
    static public func parse(_ cDict: [String: Any]) throws -> Contributor {
        let c = Contributor()
        for (k, v) in cDict {
            switch k {
            case "name":
                switch v {
                case let s as String:
                    c.multilangName.singleString = s
                case let multiString as [String: String]:
                    c.multilangName.multiString = multiString
                default:
                    throw ContributorError.invalidContributor
                }
            case "identifier":
                c.identifier = v as? String
            case "sort_as":
                c.sortAs = v as? String
            case "role":
                if let s = v as? String {
                    c.roles.append(s)
                }
            case "links":
                if let linkDict = v as? [String: Any] {
                    c.links.append(try Link.parse(linkDict: linkDict))
                }
            default:
                continue
            }
        }
        return c
    }
    
    static public func parse(contributors: Any) throws -> [Contributor] {
        var result: [Contributor] = []
        switch contributors {
        case let name as String:
            let c = Contributor()
            c.multilangName.singleString = name
            result.append(c)
        case let cDict as [String: Any]:
            let c = try parse(cDict)
            result.append(c)
        case let cArray as [String]:
            for name in cArray {
                let c = Contributor()
                c.multilangName.singleString = name
                result.append(c)
            }
        case let cArray as [[String: Any]]:
            for cDict in cArray {
                let c = try parse(cDict)
                result.append(c)
            }
        default:
            throw ContributorError.invalidContributor
        }
        return result
    }
    
}
