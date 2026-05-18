//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import ReadiumStreamer

/// Generic fallback message for errors that have no meaningful user-facing
/// description.
let unexpected = "Something went wrong. Please try again."

// MARK: - ReadiumShared Errors

extension ReadiumShared.AssetRetrieveError: UserErrorConvertible {
    var userErrorMessage: String? {
        switch self {
        case .formatNotSupported: "Unsupported file type. Please try a different file."
        case let .reading(error): error.userErrorMessage
        }
    }
}

extension ReadiumShared.AssetRetrieveURLError: UserErrorConvertible {
    var userErrorMessage: String? {
        switch self {
        case .schemeNotSupported, .formatNotSupported: "Unsupported file type. Please try a different file."
        case let .reading(error): error.userErrorMessage
        }
    }
}

extension ReadiumShared.ReadError: UserErrorConvertible {
    var userErrorMessage: String? {
        switch self {
        case let .access(error): error.userErrorMessage
        case .decoding: "We couldn't open this content. The file might be corrupted or use a format we don't support. Please try with a different file."
        case .outOfMemory: "This file is too large for the available memory."
        case .unsupportedOperation: unexpected
        case .cancelled: nil
        }
    }
}

extension ReadiumShared.AccessError: UserErrorConvertible {
    var userErrorMessage: String? {
        switch self {
        case let .http(error): error.userErrorMessage
        case let .fileSystem(error): error.userErrorMessage
        case .other: unexpected
        }
    }
}

extension ReadiumShared.FileSystemError: UserErrorConvertible {
    var userErrorMessage: String? {
        switch self {
        case .fileNotFound: "Couldn't open file. The file was not found."
        case .forbidden: "Cannot open file. Access denied."
        case .outOfSpace: "There's not enough disk space to proceed. Please free up some space and try again."
        case .io: unexpected
        }
    }
}

extension ReadiumShared.HTTPError: UserErrorConvertible {
    var userErrorMessage: String? {
        switch self {
        case .malformedRequest, .redirection, .cancelled, .other:
            "Something went wrong. Please check your internet connection or try again later."
        case .malformedResponse:
            "Cannot load this content. There's a problem with the server. Please try again later."
        case let .errorResponse(response):
            switch response.status {
            case .unauthorized: "You need to be signed in to access this content."
            case .forbidden: "You don't have permission to access this content."
            case .notFound: "Content not found."
            case .methodNotAllowed: "The server doesn't support the required loading method."
            default: unexpected
            }
        case .timeout: "Connection timed out. Please try again."
        case .unreachable: "Could not connect to the server."
        case .security: "Secure connection failed. Please try again later."
        case .rangeNotSupported: "The server doesn't support the required loading method."
        case .offline: "You're offline. Check your internet connection."
        case let .fileSystem(error): error.userErrorMessage
        }
    }
}

// MARK: - ReadiumStreamer Errors

extension ReadiumStreamer.PublicationOpenError: UserErrorConvertible {
    var userErrorMessage: String? {
        switch self {
        case .formatNotSupported: "Unsupported file type. Please try a different file."
        case let .reading(error): error.userErrorMessage
        }
    }
}
