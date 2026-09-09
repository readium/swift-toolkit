//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Errors occurring while reading a resource.
public enum ReadError: Error, Sendable {
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

    /// The content is too large to be loaded into memory safely.
    case outOfMemory(Error?)

    /// An operation could not be performed at some point.
    ///
    /// For instance, this error can occur no matter the level of indirection
    /// when trying to read ranges or getting length if any component the data
    /// has to pass through doesn't support that.
    case unsupportedOperation(Error)

    /// The task was cancelled.
    case cancelled

    public static func decoding(_ message: String, cause: Error? = nil) -> ReadError {
        .decoding(DebugError(message, cause: cause))
    }

    /// Wraps a native error into a `ReadError`, if possible.
    ///
    /// Returns `nil` if the error cannot be mapped to a known `ReadError`.
    public static func wrap(_ error: Error) -> ReadError? {
        switch error {
        case let error as ReadError:
            return error
        case is CancellationError:
            return .cancelled
        case let error as CocoaError:
            return wrap(error)
        case let error as POSIXError:
            return wrap(error)
        default:
            if let error = HTTPError.wrap(error) {
                if case .cancelled = error {
                    return .cancelled
                }
                return .access(.http(error))
            } else {
                return nil
            }
        }
    }

    private static func wrap(_ error: CocoaError) -> ReadError? {
        switch error.code {
        case .fileNoSuchFile, .fileReadNoSuchFile:
            .access(.fileSystem(.fileNotFound(error)))

        case .fileReadNoPermission, .fileWriteNoPermission:
            .access(.fileSystem(.forbidden(error)))

        case .fileWriteOutOfSpace:
            .access(.fileSystem(.outOfSpace(error)))

        case
            .fileLocking,
            .fileReadCorruptFile,
            .fileReadInvalidFileName,
            .fileReadTooLarge,
            .fileReadUnsupportedScheme,
            .fileWriteFileExists,
            .fileWriteInapplicableStringEncoding,
            .fileWriteInvalidFileName,
            .fileWriteUnknown,
            .fileWriteUnsupportedScheme,
            .fileWriteVolumeReadOnly:
            .access(.fileSystem(.io(error)))

        default:
            if let underlying = error.underlying {
                .wrap(underlying)
            } else {
                nil
            }
        }
    }

    private static func wrap(_ error: POSIXError) -> ReadError? {
        switch error.code {
        case .ENOMEM:
            .outOfMemory(error)
        case .ENOENT:
            .access(.fileSystem(.fileNotFound(error)))
        case .EPERM, .EACCES, .EAUTH:
            .access(.fileSystem(.forbidden(error)))
        case .ENOSPC, .EDQUOT:
            .access(.fileSystem(.outOfSpace(error)))
        case
            .EIO,
            .ENXIO,
            .EBADF,
            .EBUSY,
            .EEXIST,
            .ENOTDIR,
            .EISDIR,
            .ENFILE,
            .EMFILE,
            .EFBIG,
            .EROFS,
            .EMLINK,
            .ENAMETOOLONG,
            .ELOOP,
            .ENOTEMPTY,
            .ESTALE,
            .ENOLCK:
            .access(.fileSystem(.io(error)))
        default:
            nil
        }
    }
}

public extension ReadError {
    /// Indicates whether the error is caused by a cancelled task or HTTP
    /// request, instead of a genuine failure.
    ///
    /// Not made redundant by 4.0's `ReadError.wrap(_:)`. `wrap` normalises at the
    /// BOUNDARY, turning a `CancellationError` or a cancelled `HTTPError` into
    /// `.cancelled` as the error is constructed. This is a PREDICATE over an error
    /// that already exists, and it additionally unwraps `.decoding(...)` — which is
    /// how a cancellation reaches `PublicationMediaLoader` in practice. The two are
    /// complementary.
    var isCancellation: Bool {
        switch self {
        case .cancelled, .access(.http(.cancelled)):
            return true
        case let .decoding(error):
            return (error as? ReadError)?.isCancellation
                ?? (error is CancellationError)
        default:
            return false
        }
    }
}

public enum AccessError: Error, Sendable {
    /// An error occurred while accessing content over HTTP.
    case http(HTTPError)

    /// An error occurred while accessing content on the local file system.
    case fileSystem(FileSystemError)

    /// For extension purposes. This is not used in the Readium toolkit.
    case other(Error)
}
