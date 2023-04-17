//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Provides access to a `Resource` from a `Link`.
public protocol Fetcher {
    /// Known resources available in the medium, such as file paths on the file system
    /// or entries in a ZIP archive. This list is not exhaustive, and additional
    /// unknown resources might be reachable.
    ///
    /// If the medium has an inherent resource order, it should be followed.
    /// Otherwise, HREFs are sorted alphabetically.
    var links: [Link] { get }

    /// Returns the `Resource` at the given `link`'s HREF.
    ///
    /// A `Resource` is always returned, since for some cases we can't know if it exists before
    /// actually fetching it, such as HTTP. Therefore, errors are handled at the Resource level.
    func get(_ link: Link) -> Resource

    /// Closes any opened file handles, removes temporary files, etc.
    func close()
}

public extension Fetcher {
    /// Returns the `Resource` at the given `href`.
    ///
    /// A `Resource` is always returned, since for some cases we can't know if it exists before
    /// actually fetching it, such as HTTP. Therefore, errors are handled at the Resource level.
    func get(_ href: String) -> Resource {
        get(Link(href: href))
    }
}

/// A `Fetcher` providing no resources at all.
public final class EmptyFetcher: Fetcher {
    public init() {}

    public var links: [Link] { [] }

    public func get(_ link: Link) -> Resource {
        FailureResource(link: link, error: .notFound(nil))
    }

    public func close() {}
}
