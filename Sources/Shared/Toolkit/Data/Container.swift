//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A container provides access to a list of `Readable` entries.
public protocol Container: AsyncCloseable {
    associatedtype Entry: Readable

    /// Direct source to this container, when available.
    var sourceURL: AbsoluteURL? { get }
    
    /// List of all the container entries.
    var entries: Set<AnyURL> { get }
    
    /// Returns the entry at the given `url` or nil if there is none.
    subscript(url: any URLConvertible) -> Entry? { get }
}

public extension Container {
    var sourceURL: AbsoluteURL? { nil }
}

/// A `Container` providing no entries at all.
public struct EmptyContainer<Entry: Readable>: Container {

    public let entries: Set<AnyURL> = Set()
    
    public subscript(url: any URLConvertible) -> Entry? { nil }
    
    public func close() async {}
}

/// Concatenates several containers.
///
/// This can be used for example to serve a publication containing both local
/// and remote resources, and more generally to concatenate different content
/// sources.
///
/// The `containers` will be tested in the given order.
public struct CompositeContainer<Entry: Readable>: Container {

    private let containers: [AnyContainer<Entry>]

    public var entries: Set<AnyURL> {
        containers.reduce([]) { acc, container in
            acc.union(container.entries)
        }
    }

    public subscript(url: any URLConvertible) -> Entry? {
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

/// A type-erasing `Container` object
public struct AnyContainer<Entry: Readable>: Container {
    
    private let _sourceURL: () -> AbsoluteURL?
    private let _entries: () -> Set<AnyURL>
    private let _get: (URLConvertible) -> Entry?
    private let _close: () async -> Void

    public init<T: Container>(_ container: T) where T.Entry == Entry {
        _sourceURL = { container.sourceURL }
        _entries = { container.entries }
        _get = { container[$0] }
        _close = { await container.close() }
    }
    
    public var sourceURL: AbsoluteURL? { _sourceURL() }

    public var entries: Set<AnyURL> { _entries() }
    
    public subscript(url: any URLConvertible) -> Entry? {
        _get(url)
    }
    
    public func close() async {
        await _close()
    }
}

public extension Container {
    /// Returns a type-erased version of this object.
    func eraseToAnyContainer() -> AnyContainer<Entry> {
        AnyContainer(self)
    }
}

