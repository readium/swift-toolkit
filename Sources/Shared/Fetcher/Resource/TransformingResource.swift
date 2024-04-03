//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Transforms the bytes of `resource` on-the-fly.
///
/// **Warning**: The transformation runs on the full content of `resource`, so it's not appropriate
/// for large resources which can't be held in memory. Also, wrapping a `TransformingResource` in a
/// `CachingResource` can be a good idea to cache the result of the transformation in case multiple
/// ranges will be read.
///
/// You can either provide a `transform` closure during construction, or extend
/// `TransformingResource` and override `transform()`.
open class TransformingResource: ProxyResource {
    private let transformClosure: ((ResourceResult<Data>) -> ResourceResult<Data>)?

    public init(_ resource: Resource, transform: ((ResourceResult<Data>) -> ResourceResult<Data>)? = nil) {
        transformClosure = transform
        super.init(resource)
    }

    private lazy var data: ResourceResult<Data> = transform(resource.read())

    open func transform(_ data: ResourceResult<Data>) -> ResourceResult<Data> {
        transformClosure?(data) ?? data
    }

    override open var length: ResourceResult<UInt64> {
        data.map { UInt64($0.count) }
    }

    override open func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        data.map { data in
            if let range = range?.clamped(to: 0 ..< UInt64(data.count)) {
                return data[range]
            } else {
                return data
            }
        }
    }
}

/// Convenient shortcuts to create a `TransformingResource`.
public extension Resource {
    func map(transform: @escaping (Data) -> Data) -> Resource {
        TransformingResource(self, transform: { $0.map(transform) })
    }

    func mapAsString(encoding: String.Encoding? = nil, transform: @escaping (String) -> String) -> Resource {
        let encoding = encoding ?? link.mediaType.encoding ?? .utf8
        return TransformingResource(self) {
            $0.map { data in
                let string = String(data: data, encoding: encoding) ?? ""
                return transform(string).data(using: .utf8) ?? Data()
            }
        }
    }
}
