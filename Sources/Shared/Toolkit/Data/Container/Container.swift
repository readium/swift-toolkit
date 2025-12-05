//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A container provides access to a list of `Resource` entries.
public protocol Container: Closeable {
    /// URL locating this container, when available.
    ///
    /// This can be used to optimize access to a container's content for the
    /// caller. For example if the container is available on the local file
    /// system, a caller might prefer using a file handle instead of the
    /// ``Container`` API.
    ///
    /// Note that this must represent the same content available in
    /// ``Container``. If you transform the resources content on the fly (e.g.
    /// with ``TransformingContainer``), then the `sourceURL` becomes nil.
    var sourceURL: AbsoluteURL? { get }

    /// List of all the container entries.
    var entries: Set<AnyURL> { get }

    /// Returns the entry at the given `url` or nil if there is none.
    subscript(url: any URLConvertible) -> Resource? { get }
}

/// A `Container` providing no entries at all.
public struct EmptyContainer: Container {
    public init() {}

    public let sourceURL: AbsoluteURL? = nil
    public let entries: Set<AnyURL> = Set()

    public subscript(url: any URLConvertible) -> Resource? { nil }
}

/// Concatenates several containers.
///
/// This can be used for example to serve a publication containing both local
/// and remote resources, and more generally to concatenate different content
/// sources.
///
/// The `containers` will be tested in the given order.
public class CompositeContainer: Container {
    private let containers: [Container]

    public convenience init(_ containers: Container...) {
        self.init(containers)
    }

    public init(_ containers: [Container]) {
        self.containers = containers
    }

    public let sourceURL: AbsoluteURL? = nil

    public var entries: Set<AnyURL> {
        containers.reduce([]) { acc, container in
            acc.union(container.entries)
        }
    }

    public subscript(url: any URLConvertible) -> Resource? {
        containers.first { container in
            container[url]
        }
    }
}
