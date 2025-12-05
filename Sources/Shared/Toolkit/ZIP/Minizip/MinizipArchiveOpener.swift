//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An ``ArchiveOpener`` able to open ZIP archives using Minizip.
///
/// Compared to the ``ZIPFoundationArchiveOpener`` it:
/// - Does not support HTTP streaming of ZIP archives.
/// - Has better performance when reading an LCP-protected package containing
///   large deflated ZIP entries (instead of stored).
public final class MinizipArchiveOpener: ArchiveOpener {
    public init() {}

    public func open(resource: any Resource, format: Format) async -> Result<ContainerAsset, ArchiveOpenError> {
        guard
            format.conformsTo(.zip),
            let file = resource.sourceURL?.fileURL
        else {
            return .failure(.formatNotSupported(format))
        }

        return await MinizipContainer.make(file: file)
            .mapError {
                switch $0 {
                case .notAZIP:
                    return .formatNotSupported(format)
                case let .reading(error):
                    return .reading(error)
                }
            }
            .map { ContainerAsset(container: $0, format: format) }
    }

    public func sniffOpen(resource: any Resource) async -> Result<ContainerAsset, ArchiveSniffOpenError> {
        guard let file = resource.sourceURL?.fileURL else {
            return .failure(.formatNotRecognized)
        }

        return await MinizipContainer.make(file: file)
            .mapError {
                switch $0 {
                case .notAZIP:
                    return .formatNotRecognized
                case let .reading(error):
                    return .reading(error)
                }
            }
            .map {
                ContainerAsset(
                    container: $0,
                    format: Format(
                        specifications: .zip,
                        mediaType: .zip,
                        fileExtension: "zip"
                    )
                )
            }
    }
}
