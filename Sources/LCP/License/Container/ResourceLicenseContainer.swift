//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Access to a License Document packaged as a standalone LCPL file in a
/// ``Resource`` asset.
final class ResourceLicenseContainer: LicenseContainer {
    private let asset: ResourceAsset

    init(asset: ResourceAsset) {
        self.asset = asset
    }

    func containsLicense() async throws -> Bool {
        asset.format.conformsTo(.lcpLicense)
    }

    func read() async throws -> Data {
        do {
            return try await asset.resource.read().get()
        } catch {
            throw LCPError.licenseContainer(.readFailed(path: "."))
        }
    }

    var isWritable: Bool {
        asset.format.conformsTo(.lcpLicense) && asset.resource.sourceURL?.fileURL != nil
    }

    func write(_ license: LicenseDocument) async throws {
        guard let file = asset.resource.sourceURL?.fileURL else {
            throw LCPError.licenseContainer(.writeFailed(path: "."))
        }

        do {
            try license.jsonData.write(to: file.url, options: .atomic)
        } catch {
            throw LCPError.licenseContainer(.writeFailed(path: "."))
        }
    }
}
