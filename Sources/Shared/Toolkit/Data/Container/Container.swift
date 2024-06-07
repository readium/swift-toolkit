//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A container provides access to a list of `Resource` entries.
public protocol Container: AsyncCloseable {
    /// Direct source to this container, when available.
    var sourceURL: AbsoluteURL? { get }

    /// List of all the container entries.
    var entries: Set<AnyURL> { get }

    /// Returns the entry at the given `url` or nil if there is none.
    subscript(url: any URLConvertible) -> Resource? { get }
}

public extension Container {
    var sourceURL: AbsoluteURL? { nil }
}

/// A `Container` providing no entries at all.
public struct EmptyContainer: Container {
    
    public init() {}

    public let entries: Set<AnyURL> = Set()

    public subscript(url: any URLConvertible) -> Resource? { nil }

    public func close() async {}
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
    
    public init(_ containers: [Container]) {
        self.containers = containers
    }

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

    public func close() async {
        for container in containers {
            await container.close()
        }
    }
}
