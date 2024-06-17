//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An ``ArchiveOpener`` for ZIP resources.
public class ZIPArchiveOpener: ArchiveOpener {
    private let opener = MinizipArchiveOpener()

    public init() {}

    public func open(format: Format, resource: any Resource) async -> Result<ContainerAsset, ArchiveOpenError> {
        await opener.open(format: format, resource: resource)
    }

    public func sniffOpen(resource: any Resource) async -> Result<ContainerAsset, ArchiveSniffOpenError> {
        await opener.sniffOpen(resource: resource)
    }
}
