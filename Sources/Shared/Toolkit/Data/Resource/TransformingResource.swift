//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
/// You can either provide a `transform` closure during construction, or extend
/// `TransformingResource` and override `transform()`.
open class TransformingResource: Resource {
    private let resource: Resource
    private let _transform: ((ReadResult<Data>) async -> ReadResult<Data>)?

    public init(_ resource: Resource, transform: ((ReadResult<Data>) async -> ReadResult<Data>)? = nil) {
        self.resource = resource
        _transform = transform
    }

    open func transform(data: ReadResult<Data>) async -> ReadResult<Data> {
        await _transform!(data)
    }

    // As the resource is transformed, we can't use the original source URL
    // as reference.
    public let sourceURL: AbsoluteURL? = nil

    open func estimatedLength() async -> ReadResult<UInt64?> {
        // As the content will be transformed, we can't rely on the estimated
        // length from the upstream resource.
        .success(nil)
    }

    open func properties() async -> ReadResult<ResourceProperties> {
        await resource.properties()
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        await data().map { data in
            if let range = range?.clamped(to: 0 ..< UInt64(data.count)) {
                consume(data[range])
            } else {
                consume(data)
            }
            return ()
        }
    }

    private var _data: ReadResult<Data>?

    private func data() async -> ReadResult<Data> {
        if _data == nil {
            _data = await transform(data: resource.read())
        }
        return _data!
    }
}

/// Convenient shortcuts to create a `TransformingResource`.
public extension Resource {
    func map(transform: @escaping (Data) async -> Data) -> Resource {
        TransformingResource(self, transform: { await $0.asyncMap(transform) })
    }

    func mapAsString(encoding: String.Encoding = .utf8, transform: @escaping (String) -> String) -> Resource {
        TransformingResource(self) {
            $0.map { data in
                let string = String(data: data, encoding: encoding) ?? ""
                return transform(string).data(using: .utf8) ?? Data()
            }
        }
    }
}
