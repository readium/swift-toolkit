//
//  Copyright 2026 Readium Foundation. All rights reserved.
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

    private var _data: Result<Data, ReadError>?

    private func data() async throws(ReadError) -> Data {
        if _data == nil {
            do {
                _data = try await .success(resource.read())
            } catch {
                _data = .failure(error)
            }
        }
        switch _data! {
        case let .success(data): return data
        case let .failure(error): throw error
        }
    }

    public nonisolated var sourceURL: AbsoluteURL? {
        resource.sourceURL
    }

    public func properties() async throws(ReadError) -> ResourceProperties {
        try await resource.properties()
    }

    public func estimatedLength() async throws(ReadError) -> UInt64? {
        try await resource.estimatedLength()
    }

    public func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async throws(ReadError) {
        let data = try await data()
        let length = UInt64(data.count)
        if let range = range?.clamped(to: 0 ..< length) {
            consume(data[range])
        } else {
            consume(data)
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
