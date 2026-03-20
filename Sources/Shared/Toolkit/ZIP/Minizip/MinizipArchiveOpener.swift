//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
public final class MinizipArchiveOpener: ArchiveOpener, Sendable {
    public init() {}

    public func open(resource: any Resource, format: Format) async throws(ArchiveOpenError) -> ContainerAsset {
        guard
            format.conformsTo(.zip),
            let file = resource.sourceURL?.fileURL
        else {
            throw .formatNotSupported(format)
        }

        let container: MinizipContainer
        do {
            container = try await MinizipContainer.make(file: file)
        } catch {
            switch error {
            case .notAZIP:
                throw .formatNotSupported(format)
            case let .reading(readError):
                throw .reading(readError)
            }
        }
        return ContainerAsset(container: container, format: format)
    }

    public func sniffOpen(resource: any Resource) async throws(ArchiveSniffOpenError) -> ContainerAsset {
        guard let file = resource.sourceURL?.fileURL else {
            throw .formatNotRecognized
        }

        let container: MinizipContainer
        do {
            container = try await MinizipContainer.make(file: file)
        } catch {
            switch error {
            case .notAZIP:
                throw .formatNotRecognized
            case let .reading(readError):
                throw .reading(readError)
            }
        }
        return ContainerAsset(
            container: container,
            format: Format(
                specifications: .zip,
                mediaType: .zip,
                fileExtension: "zip"
            )
        )
    }
}
