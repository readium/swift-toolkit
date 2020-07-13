//
//  Resource.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Acts as a proxy to an actual resource by handling read access.
public protocol Resource {

    /// The link from which the resource was retrieved.
    ///
    /// It might be modified by the `Resource` to include additional metadata, e.g. the
    /// `Content-Type` HTTP header in `Link::type`.
    var link: Link { get }
    
    /// Data length from metadata if available, or calculated from reading the bytes otherwise.
    ///
    /// This value must be treated as a hint, as it might not reflect the actual bytes length. To
    /// get the real length, you need to read the whole resource.
    var length: ResourceResult<UInt64> { get }

    /// Reads the bytes at the given range.
    ///
    /// When `range` is `nil`, the whole content is returned. Out-of-range indexes are clamped to
    /// the available length automatically.
    func read(range: Range<UInt64>?) -> ResourceResult<Data>
    
    /// Closes any opened file handles.
    func close()

}

public extension Resource {

    func read() -> ResourceResult<Data> {
        return read(range: nil)
    }
    
    /// Reads the full content as a `String`.
    ///
    /// If `encoding` is null, then it is parsed from the `charset` parameter of `link.type`, or
    /// falls back on UTF-8.
    func readAsString(encoding: String.Encoding? = nil) -> ResourceResult<String> {
        return read().map {
            let encoding = encoding ?? link.mediaType?.encoding ?? .utf8
            return String(data: $0, encoding: encoding) ?? ""
        }
    }
    
    /// Reads the full content as a JSON object.
    func readAsJSON(options: JSONSerialization.ReadingOptions = []) -> ResourceResult<Any> {
        return read().tryMap {
            try JSONSerialization.jsonObject(with: $0, options: options)
        }
    }
    
}

/// Errors occurring while accessing a resource.
public enum ResourceError: Swift.Error {
    
    /// Equivalent to a 404 HTTP error.
    case notFound
    
    /// Equivalent to a 403 HTTP error.
    ///
    /// This can be returned when trying to read a resource protected with a DRM that is not
    /// unlocked.
    case forbidden
    
    /// Equivalent to a 503 HTTP error.
    ///
    /// Used when the source can't be reached, e.g. no Internet connection, or an issue with the
    /// file system. Usually this is a temporary error.
    case unavailable
    
    /// For any other error, such as HTTP 500.
    case other(Error)
    
    /// HTTP status code for this `ResourceError`.
    public var httpStatusCode: Int {
        switch self {
        case .notFound:
            return 404
        case .forbidden:
            return 403
        case .unavailable:
            return 503
        case .other:
            return 500
        }
    }
    
}

/// Implements the transformation of a Resource. It can be used, for example, to decrypt,
/// deobfuscate, inject CSS or JavaScript, correct content – e.g. adding a missing `dir="rtl"` in
/// an HTML document, pre-process – e.g. before indexing a publication's content, etc.
///
/// If the transformation doesn't apply, simply return resource unchanged.
public typealias ResourceTransformer = (Resource) -> Resource

/// Creates a Resource that will always return the given `error`.
public final class FailureResource: Resource {

    private let error: ResourceError
    
    public init(link: Link, error: ResourceError) {
        self.link = link
        self.error = error
    }
    
    public let link: Link
    
    public var length: ResourceResult<UInt64> { .failure(error) }

    public func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        return .failure(error)
    }
    
    public func close() {}

}

/// Creates a `Resource` serving raw data.
public final class DataResource: Resource {
    
    public typealias Factory = () -> (link: Link, data: ResourceResult<Data>)

    private let make: Factory
    private lazy var result: (link: Link, data: ResourceResult<Data>) = make()

    /// Creates a `Resource` serving an array of bytes.
    public init(make: @escaping Factory) {
        self.make = make
    }
    
    public convenience init(link: Link, makeData: @escaping (inout Link) throws -> Data = { _ in Data() }) {
        self.init {
            var link = link
            let data = ResourceResult<Data> { try makeData(&link) }
            return (link: link, data: data)
        }
    }
    
    public convenience init(link: Link, data: Data) {
        self.init {
            return (link: link, data: .success(data))
        }
    }
    
    /// Creates a `Resource` serving a string encoded as UTF-8.
    public convenience init(link: Link, string: String) {
        // It's safe to force-unwrap when using a unicode encoding.
        // https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
        self.init(link: link, data: string.data(using: .utf8)!)
    }
    
    public var link: Link { result.link }

    public var length: ResourceResult<UInt64> { result.data.map { UInt64($0.count) } }

    public func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        return result.data.map { data in
            let length = UInt64(data.count)
            if let range = range?.clamped(to: 0..<length) {
                return data[range]
            } else {
                return data
            }
        }
    }
    
    public func close() {}
    
}

/// A base class for a `Resource` which acts as a proxy to another one.
///
/// Every function is delegating to the proxied resource, and subclasses should override some of
/// them.
open class ResourceProxy: Resource {

    public let resource: Resource
    
    public init(_ resource: Resource) {
        self.resource = resource
    }
    
    open var link: Link { resource.link }

    open var length: ResourceResult<UInt64> { resource.length }
    
    open func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        return resource.read(range: range)
    }
    
    open func close() {
        resource.close()
    }
}

/// A `Resource` proxy which applies a transformation on the original content.
public class TransformingResource: ResourceProxy {
    
    private let transform: (Data) -> Data
    
    public init(_ resource: Resource, transform: @escaping (Data) -> Data) {
        self.transform = transform
        super.init(resource)
    }
    
    public override var length: ResourceResult<UInt64> {
        transformedData.map { UInt64($0.count) }
    }
    
    public override func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        return transformedData.map { data in
            if let range = range?.clamped(to: 0..<UInt64(data.count)) {
                return data[range]
            } else {
                return data
            }
        }
    }

    private lazy var transformedData: ResourceResult<Data> =
        resource.read().map(transform)

}

/// Convenient shortcuts to create a `TransformingResource`.
public extension Resource {
    
    func map(transform: @escaping (Data) -> Data) -> Resource {
        return TransformingResource(self, transform: transform)
    }
    
    func mapAsString(encoding: String.Encoding? = nil, transform: @escaping (String) -> String) -> Resource {
        let encoding = encoding ?? link.mediaType?.encoding ?? .utf8
        return TransformingResource(self) { data in
            let string = String(data: data, encoding: encoding) ?? ""
            return transform(string).data(using: .utf8) ?? Data()
        }
    }
    
}

public typealias ResourceResult<Success> = Result<Success, ResourceError>

public extension Result where Failure == ResourceError {
    
    init(block: () throws -> Success) {
        do {
            self = .success(try block())
        } catch {
            if let err = error as? ResourceError {
                self = .failure(err)
            } else {
                self = .failure(.other(error))
            }
        }
    }
    
    /// Maps the result with the given `transform`
    ///
    /// If the `transform` throws an `Error`, it is wrapped in a failure with `Resource.Error.Other`.
    func tryMap<NewSuccess>(_ transform: (Success) throws -> NewSuccess) -> ResourceResult<NewSuccess> {
        return flatMap {
            do {
                return .success(try transform($0))
            } catch {
                if let err = error as? ResourceError {
                    return .failure(err)
                } else {
                    return .failure(.other(error))
                }
            }
        }
    }
    
    func tryFlatMap<NewSuccess>(_ transform: (Success) throws -> ResourceResult<NewSuccess>) -> ResourceResult<NewSuccess> {
        return tryMap(transform).flatMap { $0 }
    }
    
}
