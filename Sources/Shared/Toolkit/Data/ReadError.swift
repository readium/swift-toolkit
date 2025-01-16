//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias ReadResult<Success> = Result<Success, ReadError>

/// Errors occurring while reading a resource.
public enum ReadError: Error {
    /// An error occurred while trying to access the content.
    ///
    /// At the moment, `AccessError`s constructed by the toolkit can be either
    /// a `FileSystemError` or an `HttpError`.
    case access(AccessError)

    /// Content doesn't match what was expected and cannot be interpreted.
    ///
    /// For instance, this error can be reported if a ZIP archive looks
    /// invalid, a publication doesn't conform to its format, or a JSON
    /// resource cannot be decoded.
    case decoding(Error)

    /// An operation could not be performed at some point.
    ///
    /// For instance, this error can occur no matter the level of indirection
    /// when trying to read ranges or getting length if any component the data
    /// has to pass through doesn't support that.
    case unsupportedOperation(Error)

    public static func decoding(_ message: String, cause: Error? = nil) -> ReadError {
        .decoding(DebugError(message, cause: cause))
    }
}

public enum AccessError: Error {
    /// An error occurred while accessing content over HTTP.
    case http(HTTPError)

    /// An error occurred while accessing content on the local file system.
    case fileSystem(FileSystemError)

    /// For extension purposes. This is not used in the Readium toolkit.
    case other(Error)
}
