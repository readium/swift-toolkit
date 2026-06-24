//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Default implementation of ``ArchiveOpener`` supporting ZIP archives.
public final class DefaultArchiveOpener: ArchiveOpener {
    private let opener: CompositeArchiveOpener

    /// - Parameter additionalArchiveOpeners: Additional archive openers to use.
    public init(additionalArchiveOpeners: [any ArchiveOpener] = []) {
        opener = CompositeArchiveOpener(additionalArchiveOpeners + [ZIPArchiveOpener()])
    }

    public func open(resource: any Resource, format: Format) async -> Result<ContainerAsset, ArchiveOpenError> {
        await opener.open(resource: resource, format: format)
    }

    public func sniffOpen(resource: any Resource) async -> Result<ContainerAsset, ArchiveSniffOpenError> {
        await opener.sniffOpen(resource: resource)
    }
}
