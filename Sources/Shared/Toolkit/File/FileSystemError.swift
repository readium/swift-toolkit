//
//  Copyright 2025 Readium Foundation. All rights reserved.
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

    /// An unexpected IO error occurred on the file system.
    case io(Error?)
}
