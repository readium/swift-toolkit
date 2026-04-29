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
    @available(*, deprecated, message: "Use ReadError.wrap() instead")
    public static func wrap(_ error: Error) -> FileSystemError? {
        guard
            case let .access(error) = ReadError.wrap(error),
            case let .fileSystem(error) = error
        else {
            return nil
        }
        return error
    }
}
