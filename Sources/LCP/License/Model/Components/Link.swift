//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// A Link to a resource.
public struct Link {
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

    init(json: [String: Any]) throws {
        guard let href = json["href"] as? String else {
            throw ParsingError.link
        }

        if let rel = json["rel"] as? String {
            self.rel = [rel]
        } else if let rel = json["rel"] as? [String], !rel.isEmpty {
            self.rel = rel
        } else {
            throw ParsingError.link
        }

        self.href = href
        title = json["title"] as? String
        type = json["type"] as? String
        templated = (json["templated"] as? Bool) ?? false
        profile = json["profile"] as? String
        length = json["length"] as? Int
        hash = json["hash"] as? String
    }

    /// Gets the valid URL if possible, applying the given template context as query parameters if the link is templated.
    /// eg. http://url{?id,name} + [id: x, name: y] -> http://url?id=x&name=y
    func url(with parameters: [String: LosslessStringConvertible]) -> URL? {
        var href = href

        if templated {
            href = URITemplate(href).expand(with: parameters.mapValues { String(describing: $0) })
        }

        return URL(string: href)
    }

    /// Expands the href without any template context.
    var url: URL? {
        url(with: [:])
    }

    var mediaType: MediaType {
        type.flatMap { MediaType.of(mediaType: $0) } ?? .binary
    }

    /// List of URI template parameter keys, if the `Link` is templated.
    var templateParameters: Set<String> {
        guard templated else {
            return []
        }
        return URITemplate(href).parameters
    }
}
