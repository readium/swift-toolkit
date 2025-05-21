//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public struct Links {
    private let links: [Link]

    init(json: [[String: Any]]) throws {
        links = try json.map(Link.init)
    }

    /// Returns all the links with the given `rel`.
    public subscript(rel: String) -> [Link] {
        links.filter { $0.rel.contains(rel) }
    }

    /// Returns the first link with the given `rel` and optional `type`.
    public func firstWithRel(_ rel: String, type: MediaType? = nil) -> Link? {
        links.first { $0.matches(rel: rel, type: type) }
    }

    /// Returns all the links with the given `rel` and optional `type`.
    public func filterWithRel(_ rel: String, type: MediaType? = nil) -> [Link] {
        links.filter { $0.matches(rel: rel, type: type) }
    }

    /// Returns the first link with the given `rel` and no media type at all.
    ///
    /// This is used to fall back when the preferred type is not found.
    func firstWithRelAndNoType(_ rel: String) -> Link? {
        links.first { $0.rel.contains(rel) && $0.type == nil }
    }
}

private extension Link {
    func matches(rel: String, type: MediaType?) -> Bool {
        self.rel.contains(rel) && (type?.matches(self.type) ?? true)
    }
}
