//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A factory to create ``Container``s from archive ``Resource``s.
public protocol ArchiveOpener {
    /// Creates a new ``ContainerAsset`` to access the entries of an archive
    /// with a known `format`.
    func open(resource: Resource, format: Format) async -> Result<ContainerAsset, ArchiveOpenError>

    /// Creates a new ``ContainerAsset`` to access the entries of an archive
    /// after sniffing its format.
    func sniffOpen(resource: Resource) async -> Result<ContainerAsset, ArchiveSniffOpenError>
}

public enum ArchiveOpenError: Error {
    /// Archive format not supported.
    case formatNotSupported(Format)

    /// An error occurred while attempting to read a resource.
    case reading(ReadError)
}

public enum ArchiveSniffOpenError: Error {
    /// The format of the resource could not be inferred.
    case formatNotRecognized

    /// An error occurred while attempting to read a resource.
    case reading(ReadError)
}
