//
//  Copyright 2025 Readium Foundation. All rights reserved.
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

    public func open(resource: any Resource, format: Format) async -> Result<ContainerAsset, ArchiveOpenError> {
        for opener in archiveOpeners {
            switch await opener.open(resource: resource, format: format) {
            case let .success(asset):
                return .success(asset)
            case let .failure(error):
                switch error {
                case .formatNotSupported:
                    continue
                case .reading:
                    return .failure(error)
                }
            }
        }

        return .failure(.formatNotSupported(format))
    }

    public func sniffOpen(resource: any Resource) async -> Result<ContainerAsset, ArchiveSniffOpenError> {
        for opener in archiveOpeners {
            switch await opener.sniffOpen(resource: resource) {
            case let .success(asset):
                return .success(asset)
            case let .failure(error):
                switch error {
                case .formatNotRecognized:
                    continue
                case .reading:
                    return .failure(error)
                }
            }
        }

        return .failure(.formatNotRecognized)
    }
}
