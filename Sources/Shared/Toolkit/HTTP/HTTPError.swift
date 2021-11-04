//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias HTTPResult<Success> = Result<Success, HTTPError>
public typealias HTTPDeferred<Success> = Deferred<Success, HTTPError>

/// Represents an error occurring during an `HTTPClient` activity.
public struct HTTPError: LocalizedError, Equatable, Loggable {

    public enum Kind: Equatable {
        /// The provided request was not valid.
        case malformedRequest(url: String?)
        /// The received response couldn't be decoded.
        case malformedResponse
        /// The client, server or gateways timed out.
        case timeout
        /// (400) The server cannot or will not process the request due to an apparent client error.
        case badRequest
        /// (401) Authentication is required and has failed or has not yet been provided.
        case unauthorized
        /// (403) The server refuses the action, probably because we don't have the necessary
        /// permissions.
        case forbidden
        /// (404) The requested resource could not be found.
        case notFound
        /// (4xx) Other client errors
        case clientError
        /// (5xx) Server errors
        case serverError
        /// The device is offline.
        case offline
        /// The request was cancelled.
        case cancelled
        /// An error whose kind is not recognized.
        case other

        public init?(statusCode: Int) {
            switch statusCode {
            case 200..<400:
                return nil
            case 400:
                self = .badRequest
            case 401:
                self = .unauthorized
            case 403:
                self = .forbidden
            case 404:
                self = .notFound
            case 405...498:
                self = .clientError
            case 499:
                self = .cancelled
            case 500...599:
                self = .serverError
            default:
                self = .malformedResponse
            }
        }

        /// Creates a `Kind` from a native `URLError` or another error.
        public init(error: Error) {
            switch error {
            case let error as HTTPError:
                self = error.kind
            case let error as URLError:
                switch error.code {
                case .badURL, .unsupportedURL:
                    self = .badRequest
                case .httpTooManyRedirects, .redirectToNonExistentLocation, .badServerResponse, .secureConnectionFailed:
                    self = .serverError
                case .zeroByteResource, .cannotDecodeContentData, .cannotDecodeRawData, .dataLengthExceedsMaximum:
                    self = .malformedResponse
                case .notConnectedToInternet, .networkConnectionLost:
                    self = .offline
                case .timedOut:
                    self = .timeout
                case .userAuthenticationRequired, .appTransportSecurityRequiresSecureConnection, .noPermissionsToReadFile:
                    self = .forbidden
                case .fileDoesNotExist:
                    self = .notFound
                case .cancelled, .userCancelledAuthentication:
                    self = .cancelled
                default:
                    self = .other
                }
            default:
                self = .other
            }
        }
    }

    /// Category of HTTP error.
    public let kind: Kind

    /// Underlying error, if any.
    public let cause: Error?

    /// Received HTTP response, if any.
    public let response: HTTPResponse?

    /// Response body parsed as a JSON problem details.
    public let problemDetails: HTTPProblemDetails?

    public init(kind: Kind, cause: Error? = nil, response: HTTPResponse? = nil) {
        self.kind = kind
        self.cause = cause
        self.response = response

        self.problemDetails = {
            if let body = response?.body, response?.mediaType.matches(.problemDetails) == true {
                do {
                    return try HTTPProblemDetails(data: body)
                } catch {
                    HTTPError.log(.error, "Failed to parse the JSON problem details: \(error)")
                }
            }
            return nil
        }()
    }

    public init?(response: HTTPResponse) {
        guard let kind = Kind(statusCode: response.statusCode) else {
            return nil
        }
        self.init(kind: kind, response: response)
    }

    /// Creates an `HTTPError` from a native `URLError` or another error.
    public init(error: Error) {
        if let error = error as? HTTPError {
            self = error
            return
        }

        self.init(kind: Kind(error: error), cause: error)
    }

    public var errorDescription: String? {
        if var message = problemDetails?.title {
            if let detail = problemDetails?.detail {
                message += "\n" + detail
            }
            return message
        }

        switch kind {
        case .malformedRequest:
            return R2SharedLocalizedString("HTTPError.malformedRequest")
        case .malformedResponse:
            return R2SharedLocalizedString("HTTPError.malformedResponse")
        case .timeout:
            return R2SharedLocalizedString("HTTPError.timeout")
        case .badRequest:
            return R2SharedLocalizedString("HTTPError.badRequest")
        case .unauthorized:
            return R2SharedLocalizedString("HTTPError.unauthorized")
        case .forbidden:
            return R2SharedLocalizedString("HTTPError.forbidden")
        case .notFound:
            return R2SharedLocalizedString("HTTPError.notFound")
        case .clientError:
            return R2SharedLocalizedString("HTTPError.clientError")
        case .serverError:
            return R2SharedLocalizedString("HTTPError.serverError")
        case .cancelled:
            return R2SharedLocalizedString("HTTPError.cancelled")
        case .offline:
            return R2SharedLocalizedString("HTTPError.offline")
        case .other:
            return (cause as? LocalizedError)?.errorDescription
        }
    }

    public static func ==(lhs: HTTPError, rhs: HTTPError) -> Bool {
        return lhs.kind == rhs.kind
            && lhs.response == rhs.response
            && lhs.problemDetails == rhs.problemDetails
    }

}
