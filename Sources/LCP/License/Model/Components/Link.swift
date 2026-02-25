//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A Link to a resource.
public struct Link: Sendable {
    /// The link destination.
    public let href: String
    /// Indicates the relationship between the resource and its containing collection.
    public let rel: [String]
    /// Title for the Link.
    public let title: String?
    /// Expected MIME media type value for the external resources.
    public let type: String?
    /// Indicates that the linked resource is a URI template.
    public let templated: Bool
    /// Expected profile used to identify the external resource. (URI)
    public let profile: String?
    /// Content length in octets.
    public let length: Int?
    /// SHA-256 hash of the resource.
    public let hash: String?

    init(json: JSONValue?) throws {
        guard var json = JSONDictionary(json),
              let href = json.pop("href")?.string
        else {
            throw ParsingError.link
        }

        let rel: [String] = parseArray(json.pop("rel"), allowingSingle: true)
        guard !rel.isEmpty else {
            throw ParsingError.link
        }

        self.href = href
        self.rel = rel
        title = json.pop("title")?.string
        type = json.pop("type")?.string
        templated = json.pop("templated")?.bool ?? false
        profile = json.pop("profile")?.string
        length = json.pop("length")?.integer
        hash = json.pop("hash")?.string
    }

    init(json: [String: Any]) throws {
        try self.init(json: JSONValue(json))
    }

    /// Gets the valid URL if possible, applying the given template context as query parameters if the link is templated.
    /// eg. http://url{?id,name} + [id: x, name: y] -> http://url?id=x&name=y
    public func url(parameters: [String: LosslessStringConvertible] = [:]) -> HTTPURL? {
        var href = href

        if templated {
            href = URITemplate(href).expand(with: parameters.mapValues { String(describing: $0) })
        }

        return HTTPURL(string: href)
    }

    public var mediaType: MediaType? {
        type.flatMap { MediaType($0) }
    }

    /// List of URI template parameter keys, if the `Link` is templated.
    public var templateParameters: Set<String> {
        guard templated else {
            return []
        }
        return URITemplate(href).parameters
    }
}
