//
//  Contributors.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 2/16/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

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

}

extension Contributor: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case name
        case sortAs
        case identifier
        case roles
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encode(multilangName, forKey: .name)
        if !roles.isEmpty {
            try container.encode(roles, forKey: .roles)
        }
        try container.encodeIfPresent(sortAs, forKey: .sortAs)
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
                }else if let array = v as? [[String: Any]] {
                    for dict in array {
                        c.links.append(try Link.parse(linkDict: dict))
                    }
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
