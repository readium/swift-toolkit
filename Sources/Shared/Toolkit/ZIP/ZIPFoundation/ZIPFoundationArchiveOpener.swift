//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An ``ArchiveOpener`` able to open ZIP archives using ZIPFoundation.
public final class ZIPFoundationArchiveOpener: ArchiveOpener, Sendable {
    public init() {}

    public func open(resource: any Resource, format: Format) async throws(ArchiveOpenError) -> ContainerAsset {
        guard format.conformsTo(.zip) else {
            throw .formatNotSupported(format)
        }

        let container: ZIPFoundationContainer
        do {
            container = try await ZIPFoundationContainer.make(resource: resource)
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
        let container: ZIPFoundationContainer
        do {
            container = try await ZIPFoundationContainer.make(resource: resource)
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
