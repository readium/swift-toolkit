//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias HTTPResult<Success> = Result<Success, HTTPError>

/// Represents an error occurring during an `HTTPClient` activity.
public enum HTTPError: Error, Loggable {
    /// The provided request was not valid.
    case malformedRequest(url: String?)

    /// The received response couldn't be decoded.
    case malformedResponse(Error?)

    /// The server returned a response with an HTTP status error.
    case errorResponse(HTTPResponse)

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
        guard
            case let .errorResponse(response) = self,
            response.mediaType?.matches(.problemDetails) == true,
            let body = response.body
        else {
            return nil
        }

        return try HTTPProblemDetails(data: body)
    }
}
