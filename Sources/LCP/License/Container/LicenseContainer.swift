//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Encapsulates the read/write access to the packaged License Document (eg. in an EPUB container, or a standalone LCPL file)
protocol LicenseContainer {
    /// Returns whether this container currently contains a License Document.
    ///
    /// For example, when fulfilling an EPUB publication, it initially doesn't contain the license.
    func containsLicense() async throws -> Bool

    func read() async throws -> Data
    func write(_ license: LicenseDocument) async throws
}

func makeLicenseContainer(for asset: Asset) throws -> LicenseContainer {
    switch asset {
    case let .resource(asset):
        guard
            asset.format.conformsTo(.lcpLicense),
            let file = asset.resource.sourceURL?.fileURL
        else {
            throw LCPError.licenseContainer(ContainerError.openFailed(nil))
        }
        return LCPLLicenseContainer(lcpl: file)

    case let .container(asset):
        guard
            asset.format.conformsTo(.zip),
            let file = asset.container.sourceURL?.fileURL
        else {
            throw LCPError.licenseContainer(ContainerError.openFailed(nil))
        }

        if asset.format.conformsTo(.epub) {
            return EPUBLicenseContainer(epub: file)
        } else {
            return ReadiumLicenseContainer(path: file)
        }
    }
}
