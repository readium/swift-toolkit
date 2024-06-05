//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Provides access to a `Resource` from a `Link`.
@available(*, unavailable, message: "Use a `Container` instead")
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

/// A `Fetcher` providing no resources at all.
@available(*, unavailable, message: "Use an `EmptyContainer` instead")
public final class EmptyFetcher {}

@available(*, unavailable, message: "Use a `TransformingContainer` instead")
public final class TransformingFetcher {}

@available(*, unavailable, message: "Not available anymore")
public final class RoutingFetcher {}

@available(*, unavailable, message: "Use an `HTTPContainer` instead")
public final class HTTPFetcher {}

@available(*, unavailable, message: "Use an `FileContainer` instead")
public final class FileFetcher {}
