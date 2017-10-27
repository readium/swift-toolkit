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
