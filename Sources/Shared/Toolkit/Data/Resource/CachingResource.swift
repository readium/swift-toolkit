//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Caches the members of `resource` on first access, to optimize subsequent accesses.
///
/// This can be useful when reading `resource` is expensive.
///
/// **Warning**: Bytes are read and cached entirely the first time, even if only a `range` is
/// requested. So this is not appropriate for large resources.
public actor CachingResource: Resource {
    private nonisolated let resource: Resource

    public init(resource: Resource) {
        self.resource = resource
    }

    private var data: ReadResult<Data>?

    private func data() async -> ReadResult<Data> {
        if data == nil {
            data = await resource.read()
        }
        return data!
    }

    public nonisolated var sourceURL: AbsoluteURL? { resource.sourceURL }

    public func properties() async -> ReadResult<ResourceProperties> {
        await resource.properties()
    }

    public func estimatedLength() async -> ReadResult<UInt64?> {
        await resource.estimatedLength()
    }

    public func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async -> ReadResult<Void> {
        await data().map { data in
            let length = UInt64(data.count)
            if let range = range?.clamped(to: 0 ..< length) {
                consume(data[range])
            } else {
                consume(data)
            }
            return ()
        }
    }
}

public extension Resource {
    /// Creates a cached resource wrapping this resource.
    func cached() -> CachingResource {
        self as? CachingResource
            ?? CachingResource(resource: self)
    }
}
