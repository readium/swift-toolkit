//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An ``ArchiveOpener`` for ZIP resources.
public final class ZIPArchiveOpener: ArchiveOpener {
    private let opener: CompositeArchiveOpener

    public init() {
        opener = CompositeArchiveOpener([
            MinizipArchiveOpener(),
            ZIPFoundationArchiveOpener(),
        ])
    }

    public func open(resource: any Resource, format: Format) async -> Result<ContainerAsset, ArchiveOpenError> {
        await opener.open(resource: resource, format: format)
    }

    public func sniffOpen(resource: any Resource) async -> Result<ContainerAsset, ArchiveSniffOpenError> {
        await opener.sniffOpen(resource: resource)
    }
}
