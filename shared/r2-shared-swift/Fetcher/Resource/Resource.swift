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
    func readAsJSON(options: JSONSerialization.ReadingOptions = []) -> ResourceResult<[String: Any]> {
        return read().tryMap {
            guard let json = try JSONSerialization.jsonObject(with: $0, options: options) as? [String: Any] else {
                throw JSONError.parsing([String: Any].self)
            }
            return json
        }
    }
    
}

/// Errors occurring while accessing a resource.
public enum ResourceError: LocalizedError {
    
    /// Equivalent to a 400 HTTP error.
    ///
    /// This can be used for templated HREFs, when the provided arguments are invalid.
    case badRequest(Error)
    
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
        case .badRequest:
            return 400
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
    
    public static func wrap(_ error: Error) -> ResourceError {
        return error as? ResourceError
            ?? .other(error)
    }
    
    public var errorDescription: String? {
        switch self {
        case .badRequest:
            return R2SharedLocalizedString("Publication.ResourceError.badRequest")
        case .notFound:
            return R2SharedLocalizedString("Publication.ResourceError.notFound")
        case .forbidden:
            return R2SharedLocalizedString("Publication.ResourceError.forbidden")
        case .unavailable:
            return R2SharedLocalizedString("Publication.ResourceError.unavailable")
        case .other:
            return R2SharedLocalizedString("Publication.ResourceError.other")
        }
    }
    
}

/// Implements the transformation of a Resource. It can be used, for example, to decrypt,
/// deobfuscate, inject CSS or JavaScript, correct content – e.g. adding a missing `dir="rtl"` in
/// an HTML document, pre-process – e.g. before indexing a publication's content, etc.
///
/// If the transformation doesn't apply, simply return resource unchanged.
public typealias ResourceTransformer = (Resource) -> Resource

public typealias ResourceResult<Success> = Result<Success, ResourceError>

public extension Result where Failure == ResourceError {

    init(block: () throws -> Success) {
        do {
            self = .success(try block())
        } catch {
            self = .failure(.wrap(error))
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
                return .failure(.wrap(error))
            }
        }
    }
    
    func tryFlatMap<NewSuccess>(_ transform: (Success) throws -> ResourceResult<NewSuccess>) -> ResourceResult<NewSuccess> {
        return tryMap(transform).flatMap { $0 }
    }
    
}
