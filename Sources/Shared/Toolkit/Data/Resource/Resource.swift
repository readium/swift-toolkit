//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Acts as a proxy to an actual resource by handling read access.
public protocol Resource: Streamable {
    /// URL locating this resource, if any.
    var sourceURL: AbsoluteURL? { get }

    /// Properties associated to the resource.
    ///
    /// This is opened for extensions.
    func properties() async -> ReadResult<ResourceProperties>
}

/// Properties associated to a resource.
public struct ResourceProperties {
    public var properties: [String: Any]

    public init(_ properties: [String: Any] = [:]) {
        self.properties = properties
    }

    public subscript<T>(_ key: String) -> T? {
        get { properties[key] as? T }
        set {
            if let newValue = newValue {
                properties[key] = newValue
            } else {
                properties.removeValue(forKey: key)
            }
        }
    }
}

public extension Resource {
    @available(*, unavailable, message: "Not available anymore in a Resource")
    var link: Link { fatalError() }

    @available(*, unavailable, message: "Use the async variant")
    var length: ResourceResult<UInt64> { fatalError() }

    @available(*, deprecated, renamed: "sourceURL")
    var file: FileURL? { fatalError() }

    @available(*, unavailable, message: "Use the async variant")
    func read(range: Range<UInt64>?) -> ResourceResult<Data> { fatalError() }

    @available(*, deprecated, message: "Use the async variant")
    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void, completion: @escaping (ResourceResult<Void>) -> Void) -> Cancellable {
        fatalError()
    }
}

/// Errors occurring while accessing a resource.
@available(*, deprecated, message: "Not used anymore")
public enum ResourceError: LocalizedError {
    /// Equivalent to a 400 HTTP error.
    ///
    /// This can be used for templated HREFs, when the provided arguments are invalid.
    case badRequest(Error)

    /// Equivalent to a 404 HTTP error.
    case notFound(Error?)

    /// Equivalent to a 403 HTTP error.
    ///
    /// This can be returned when trying to read a resource protected with a DRM that is not
    /// unlocked.
    case forbidden(Error?)

    /// Equivalent to a 503 HTTP error.
    ///
    /// Used when the source can't be reached, e.g. no Internet connection, or an issue with the
    /// file system. Usually this is a temporary error.
    case unavailable(Error?)

    /// The request was cancelled.
    ///
    /// For example, an HTTP request was cancelled by the caller.
    case cancelled

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
        case .cancelled:
            return 499 // nginx's Client Closed Request
        case .other:
            return 500
        }
    }

    public static func wrap(_ error: Error) -> ResourceError {
        switch error {
        case let error as ResourceError:
            return error
        case let error as HTTPError:
            switch error.kind {
            case .malformedRequest, .badRequest:
                return .badRequest(error)
            case .timeout, .offline, .serverUnreachable:
                return .unavailable(error)
            case .unauthorized, .forbidden:
                return .forbidden(error)
            case .notFound:
                return .notFound(error)
            case .cancelled:
                return .cancelled
            case .malformedResponse, .clientError, .serverError, .ioError, .other:
                return .other(error)
            }
        default:
            return .other(error)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .badRequest:
            return ReadiumSharedLocalizedString("Publication.ResourceError.badRequest")
        case .notFound:
            return ReadiumSharedLocalizedString("Publication.ResourceError.notFound")
        case .forbidden:
            return ReadiumSharedLocalizedString("Publication.ResourceError.forbidden")
        case .unavailable:
            return ReadiumSharedLocalizedString("Publication.ResourceError.unavailable")
        case .cancelled:
            return ReadiumSharedLocalizedString("Publication.ResourceError.cancelled")
        case .other:
            return ReadiumSharedLocalizedString("Publication.ResourceError.other")
        }
    }
}

@available(*, deprecated, message: "Not used anymore")
public typealias ResourceResult<Success> = Result<Success, ResourceError>
