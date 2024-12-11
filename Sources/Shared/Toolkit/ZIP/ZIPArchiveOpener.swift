//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An ``ArchiveOpener`` for ZIP resources.
public class ZIPArchiveOpener: ArchiveOpener {
//    private let opener = MinizipArchiveOpener()

    public init() {}

    public func open(resource: any Resource, format: Format) async -> Result<ContainerAsset, ArchiveOpenError> {
        return .failure(.formatNotSupported(format))
//        await opener.open(resource: resource, format: format)
    }

    public func sniffOpen(resource: any Resource) async -> Result<ContainerAsset, ArchiveSniffOpenError> {
        return .failure(.formatNotRecognized)
//        await opener.sniffOpen(resource: resource)
    }
}
