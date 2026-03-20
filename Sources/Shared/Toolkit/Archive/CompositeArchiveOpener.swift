//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A composite ``ArchiveOpener`` which tries several factories until it finds
/// one which supports the format.
public class CompositeArchiveOpener: ArchiveOpener {
    private let archiveOpeners: [ArchiveOpener]

    public init(_ archiveOpeners: [ArchiveOpener]) {
        self.archiveOpeners = archiveOpeners
    }

    public func open(resource: any Resource, format: Format) async throws(ArchiveOpenError) -> ContainerAsset {
        for opener in archiveOpeners {
            do {
                return try await opener.open(resource: resource, format: format)
            } catch {
                switch error {
                case .formatNotSupported:
                    continue
                case .reading:
                    throw error
                }
            }
        }

        throw .formatNotSupported(format)
    }

    public func sniffOpen(resource: any Resource) async throws(ArchiveSniffOpenError) -> ContainerAsset {
        for opener in archiveOpeners {
            do {
                return try await opener.sniffOpen(resource: resource)
            } catch {
                switch error {
                case .formatNotRecognized:
                    continue
                case .reading:
                    throw error
                }
            }
        }

        throw .formatNotRecognized
    }
}
