//
//  Contributor.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// https://readium.org/webpub-manifest/schema/contributor-object.schema.json
public struct Contributor: Equatable {
    
    /// The name of the contributor.
    public var localizedName: LocalizedString
    public var name: String {
        return localizedName.string
    }

    /// An unambiguous reference to this contributor.
    public var identifier: String?
    
    /// The string used to sort the name of the contributor.
    public var sortAs: String?
    
    /// The role of the contributor in the publication making.
    public var roles: [String] = []
    
    /// The position of the publication in this collection/series, when the contributor represents a collection.
    public var position: Double?
    
    /// Used to retrieve similar publications for the given contributor.
    public var links: [Link] = []

    public init(name: LocalizedStringConvertible, identifier: String? = nil, sortAs: String? = nil, roles: [String] = [], role: String? = nil, position: Double? = nil, links: [Link] = []) {
        self.localizedName = name.localizedString
        self.identifier = identifier
        self.sortAs = sortAs
        self.roles = roles
        self.position = position
        self.links = links
        
        // convenience to set a single role during construction
        if let role = role {
            self.roles.append(role)
        }
    }
    
    public init(json: Any, normalizeHref: (String) -> String = { $0 }) throws {
        if let name = json as? String {
            self.localizedName = name.localizedString
            
        } else if let json = json as? [String: Any] {
            guard let name = try LocalizedString(json: json["name"]) else {
                throw JSONError.parsing(Contributor.self)
            }
            self.localizedName = name
            self.identifier = json["identifier"] as? String
            self.sortAs = json["sortAs"] as? String
            self.roles = parseArray(json["role"], allowingSingle: true)
            self.position =  parseDouble(json["position"])
            self.links = [Link](json: json["links"], normalizeHref: normalizeHref)

        } else {
            throw JSONError.parsing(Contributor.self)
        }
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "name": localizedName.json,
            "identifier": encodeIfNotNil(identifier),
            "sortAs": encodeIfNotNil(sortAs),
            "role": encodeIfNotEmpty(roles),
            "position": encodeIfNotNil(position),
            "links": encodeIfNotEmpty(links.json)
        ])
    }

}

extension Array where Element == Contributor {
    
    /// Parses multiple JSON contributors into an array of Contributors.
    /// eg. let authors = [Contributor](json: ["Apple", "Pear"])
    public init(json: Any?, normalizeHref: (String) -> String = { $0 }) {
        self.init()
        guard let json = json else {
            return
        }

        if let json = json as? [Any] {
            let contributors = json.compactMap { try? Contributor(json: $0, normalizeHref: normalizeHref) }
            append(contentsOf: contributors)
        } else if let contributor = try? Contributor(json: json, normalizeHref: normalizeHref) {
            append(contributor)
        }
    }
    
    public var json: [[String: Any]] {
        return map { $0.json }
    }
    
}
