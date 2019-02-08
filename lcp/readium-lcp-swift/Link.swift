//
//  Link.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/8/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SwiftyJSON

/// A Link to a resource.
public class Link {
    /// The link destination.
    public var href: URL
    /// Indicates the relationship between the resource and its containing collection.
    public var rel = [String]()
    /// Title for the Link.
    public var title: String?
    /// MIME type of resource.
    public var type: String?
    /// Indicates that the linked resource is a URI template.
    public var templated: Bool?
    /// Expected profile used to identify the external resource. (URI)
    public var profile: URL?
    /// Content length in octets.
    public var length: Int?
    /// SHA-256 hash of the resource.
    public var hash: String?

    /// Link initializer
    ///
    /// - Parameter json: The JSON representation of the Link object.
    /// - Throws: LcpErrors.
    public init(with json: JSON) throws {
        // Retrieves the non optional fields.
        guard let href = json["href"].url else {
            throw ParsingError.link
        }
        self.href = href
        if let rel = json["rel"].array {
            for element in rel {
                if let relation = element.string {
                    self.rel.append(relation)
                }
            }
        } else if let rel = json["rel"].string {
            self.rel.append(rel)
        } else {
            throw ParsingError.link
        }
        guard !self.rel.isEmpty else {
            throw ParsingError.link
        }
        title = json["title"].string
        type = json["type"].string
        templated = json["templated"].bool
        profile = json["profile"].url
        length = json["length"].int
        hash = json["hash"].string
    }
}

/// Parses the Links.
///
/// - Parameter json: The JSON object representing the Links.
/// - Throws: LsdErrors.
func parseLinks(_ json: JSON) throws -> [Link] {
    guard let jsonLinks = json.array else {
        throw ParsingError.json
    }
    var links = [Link]()

    for jsonLink in jsonLinks {
        let link = try Link.init(with: jsonLink)

        links.append(link)
    }
    return links
}
