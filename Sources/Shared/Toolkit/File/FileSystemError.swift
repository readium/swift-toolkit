//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Error occurring on the file system.
public enum FileSystemError: Error {
    /// File was not found.
    case fileNotFound(Error?)

    /// You are not allowed to access this file.
    case forbidden(Error?)

    /// The file storage is out of space.
    case outOfSpace(Error?)

    /// An unexpected IO error occurred on the file system.
    case io(Error?)

    /// Wraps a native error into a `FileSystemError`, if possible.
    ///
    /// Returns `nil` if the error is not related to the file system.
    public static func wrap(_ error: Error) -> FileSystemError? {
        if let error = error as? CocoaError {
            return switch error.code {
            case .fileNoSuchFile, .fileReadNoSuchFile:
                .fileNotFound(error)

            case .fileReadNoPermission, .fileWriteNoPermission:
                .forbidden(error)

            case .fileWriteOutOfSpace:
                .outOfSpace(error)

            case
                .fileLocking,
                .fileReadCorruptFile,
                .fileReadInvalidFileName,
                .fileReadTooLarge,
                .fileReadUnknown,
                .fileReadUnsupportedScheme,
                .fileWriteFileExists,
                .fileWriteInapplicableStringEncoding,
                .fileWriteInvalidFileName,
                .fileWriteUnknown,
                .fileWriteUnsupportedScheme,
                .fileWriteVolumeReadOnly:
                .io(error)

            default:
                nil
            }
        } else if let error = error as? POSIXError {
            return switch error.code {
            case .ENOENT:
                .fileNotFound(error)
            case .EPERM, .EACCES, .EAUTH:
                .forbidden(error)
            case .ENOSPC, .EDQUOT:
                .outOfSpace(error)
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
                .io(error)
            default:
                nil
            }
        }
        return nil
    }
}
