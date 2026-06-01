//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias HTTPResult<Success> = Result<Success, HTTPError>

/// Represents an error occurring during an `HTTPClient` activity.
public enum HTTPError: Error, Loggable, Sendable {
    /// The provided request was not valid.
    case malformedRequest(url: String?)

    /// The received response couldn't be decoded.
    case malformedResponse(Error?)

    /// The server returned a response with an HTTP status error.
    case errorResponse(HTTPErrorResponse)

    /// The client, server or gateways timed out.
    case timeout(Error?)

    /// Cannot connect to the server, or the host cannot be resolved.
    case unreachable(Error?)

    /// Redirection failed.
    case redirection(Error?)

    /// Cannot open a secure connection to the server, for example because of
    /// a failed SSL handshake.
    case security(Error?)

    /// A Range header was used in the request, but the server does not support
    /// byte range requests. The request was cancelled.
    case rangeNotSupported

    /// The device appears offline.
    case offline(Error?)

    /// IO error while accessing the disk.
    case fileSystem(FileSystemError)

    /// The request was cancelled.
    case cancelled

    /// An other unknown error occurred.
    case other(Error)

    /// Response body parsed as a JSON problem details.
    public func problemDetails() throws -> HTTPProblemDetails? {
        guard case let .errorResponse(response) = self else {
            return nil
        }
        return try response.problemDetails()
    }

    /// Wraps a native error into an `HTTPError`, if possible.
    ///
    /// Returns `nil` if the error is not related to HTTP.
    public static func wrap(_ error: Error) -> HTTPError? {
        guard let error = error as? URLError else {
            return nil
        }
        return switch error.code {
        case .httpTooManyRedirects, .redirectToNonExistentLocation:
            .redirection(error)
        case .secureConnectionFailed, .clientCertificateRejected, .clientCertificateRequired, .appTransportSecurityRequiresSecureConnection, .userAuthenticationRequired:
            .security(error)
        case .badServerResponse, .zeroByteResource, .cannotDecodeContentData, .cannotDecodeRawData, .dataLengthExceedsMaximum:
            .malformedResponse(error)
        case .notConnectedToInternet, .networkConnectionLost:
            .offline(error)
        case .cannotConnectToHost, .cannotFindHost:
            .unreachable(error)
        case .timedOut:
            .timeout(error)
        case .cancelled, .userCancelledAuthentication:
            .cancelled
        default:
            .other(error)
        }
    }
}

/// Response returned by the server with an HTTP status error.
public struct HTTPErrorResponse: Equatable, Sendable, HTTPHeadersProviding {
    /// HTTP status code returned by the server.
    public let status: HTTPStatus

    /// The raw data received in the response body.
    public let body: Data

    /// Media type provided in the `Content-Type` header.
    public let mediaType: MediaType?

    /// HTTP response headers, indexed by their name.
    public let headers: [String: String]

    public init(
        status: HTTPStatus,
        body: Data = Data(),
        mediaType: MediaType? = nil,
        headers: [String: String] = [:]
    ) {
        self.status = status
        self.body = body
        self.mediaType = mediaType
        self.headers = headers
    }

    /// Response body parsed as a JSON problem details.
    public func problemDetails() throws -> HTTPProblemDetails? {
        guard
            mediaType?.matches(.problemDetails) == true,
            !body.isEmpty
        else {
            return nil
        }

        return try HTTPProblemDetails(data: body)
    }
}
