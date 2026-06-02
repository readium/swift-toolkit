//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Transforms the bytes of `resource` on-the-fly.
///
/// **Warning**: The transformation runs on the full content of `resource`, so
/// it's not appropriate for large resources which can't be held in memory.
/// Also, wrapping a `TransformingResource` in a `CachingResource` can be a
/// good idea to cache the result of the transformation in case multiple ranges
/// will be read.
///
/// Customize the transformation by providing a `transform` closure during construction.
public final class TransformingResource: Resource, Sendable {
    private let resource: Resource
    private let data: AsyncMemoizer<ReadResult<Data>>

    public init(
        _ resource: Resource,
        transform: @escaping @Sendable (ReadResult<Data>) async -> ReadResult<Data> = { $0 }
    ) {
        self.resource = resource
        data = AsyncMemoizer {
            await transform(resource.read())
        }
    }

    /// As the resource is transformed, we can't use the original source URL
    /// as reference.
    public let sourceURL: AbsoluteURL? = nil

    public func estimatedLength() async -> ReadResult<UInt64?> {
        // As the content will be transformed, we can't rely on the estimated
        // length from the upstream resource.
        .success(nil)
    }

    public func properties() async -> ReadResult<ResourceProperties> {
        await resource.properties()
    }

    public func stream(range: Range<UInt64>?, consume: @escaping @Sendable (Data) -> Void) async -> ReadResult<Void> {
        await data().map { data in
            if let range = range?.clamped(to: 0 ..< UInt64(data.count)) {
                consume(data[range])
            } else {
                consume(data)
            }
            return ()
        }
    }
}

/// Convenient shortcuts to create a `TransformingResource`.
public extension Resource {
    func map(transform: @escaping @Sendable (Data) async -> Data) -> Resource {
        TransformingResource(self, transform: { await $0.asyncMap(transform) })
    }

    func mapAsString(encoding: String.Encoding = .utf8, transform: @escaping @Sendable (String) async -> String) -> Resource {
        TransformingResource(self, transform: {
            await $0.asyncMap { data in
                let string = String(data: data, encoding: encoding) ?? ""
                return await transform(string).data(using: .utf8) ?? Data()
            }
        })
    }
}
