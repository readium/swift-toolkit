//
//  WPContributor.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// https://readium.org/webpub-manifest/schema/contributor-object.schema.json
public struct WPContributor: Equatable {
    
    public var name: WPLocalizedString
    public var identifier: String?
    public var sortAs: String?
    public var roles: [String] = []
    public var position: Double?
    public var links: [Link] = []
    
    public init(name: WPLocalizedString, identifier: String? = nil, sortAs: String? = nil, roles: [String] = [], position: Double? = nil, links: [Link] = []) {
        self.name = name
        self.identifier = identifier
        self.sortAs = sortAs
        self.roles = roles
        self.position = position
        self.links = links
    }
    
    public init(json: Any) throws {
        if let name = json as? String {
            self.name = .nonlocalized(name)
            
        } else if let json = json as? [String: Any] {
            guard let name = try WPLocalizedString(json: json["name"]) else {
                throw JSONParsingError.contributor
            }
            self.name = name
            self.identifier = json["identifier"] as? String
            self.sortAs = json["sortAs"] as? String
            self.roles = parseArray(json["role"], allowingSingle: true)
            self.position =  parseDouble(json["position"])
            self.links = [Link](json: json["links"])

        } else {
            throw JSONParsingError.contributor
        }
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "name": name.json,
            "identifier": encodeIfNotNil(identifier),
            "sortAs": encodeIfNotNil(sortAs),
            "role": encodeIfNotEmpty(roles),
            "position": encodeIfNotNil(position),
            "links": encodeIfNotEmpty(links.json)
        ])
    }

}

extension Array where Element == WPContributor {
    
    /// Parses multiple JSON contributors into an array of WPContributors.
    /// eg. let authors = [WPContributor](json: ["Apple", "Pear"])
    public init(json: Any?) {
        self.init()
        guard let json = json else {
            return
        }

        if let json = json as? [Any] {
            let contributors = json.compactMap { try? WPContributor(json: $0) }
            append(contentsOf: contributors)
        } else if let contributor = try? WPContributor(json: json) {
            append(contributor)
        }
    }
    
    public var json: [[String: Any]] {
        return map { $0.json }
    }
    
}
