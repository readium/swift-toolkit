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
/// You can either provide a `transform` closure during construction, or extend
/// `TransformingResource` and override `transform()`.
open class TransformingResource: Resource {
    private let resource: Resource
    private let _transform: ((Data) async throws(ReadError) -> Data)?

    public init(_ resource: Resource, transform: ((Data) async throws(ReadError) -> Data)? = nil) {
        self.resource = resource
        _transform = transform
    }

    open func transform(data: Data) async throws(ReadError) -> Data {
        try await _transform!(data)
    }

    /// As the resource is transformed, we can't use the original source URL
    /// as reference.
    public let sourceURL: AbsoluteURL? = nil

    open func estimatedLength() async throws(ReadError) -> UInt64? {
        // As the content will be transformed, we can't rely on the estimated
        // length from the upstream resource.
        nil
    }

    open func properties() async throws(ReadError) -> ResourceProperties {
        try await resource.properties()
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async throws(ReadError) {
        let data = try await data()
        if let range = range?.clamped(to: 0 ..< UInt64(data.count)) {
            consume(data[range])
        } else {
            consume(data)
        }
    }

    private var _data: Result<Data, ReadError>?

    private func data() async throws(ReadError) -> Data {
        if _data == nil {
            do {
                let rawData = try await resource.read()
                _data = try await .success(transform(data: rawData))
            } catch {
                _data = .failure(error)
            }
        }
        switch _data! {
        case let .success(data): return data
        case let .failure(error): throw error
        }
    }
}

/// Convenient shortcuts to create a `TransformingResource`.
public extension Resource {
    func map(transform: @escaping (Data) async -> Data) -> Resource {
        TransformingResource(self, transform: { data in await transform(data) })
    }

    func mapAsString(encoding: String.Encoding = .utf8, transform: @escaping (String) async -> String) -> Resource {
        TransformingResource(self) { data in
            let string = String(data: data, encoding: encoding) ?? ""
            return await transform(string).data(using: .utf8) ?? Data()
        }
    }
}
