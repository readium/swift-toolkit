//
//  Fetcher.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
        return get(Link(href: href))
    }

}

/// A `Fetcher` providing no resources at all.
public final class EmptyFetcher: Fetcher {
    
    public init() {}
    
    public var links: [Link] { [] }
    
    public func get(_ link: Link) -> Resource {
        return FailureResource(link: link, error: .notFound)
    }

    public func close() {}

}
