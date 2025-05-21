//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import ReadiumZIPFoundation

/// Access to a License Document stored in a ``Container``.
/// Meant to be subclassed to customize the pathInZIP property,
/// eg. ``EPUBLicenseContainer``.
class ContainerLicenseContainer: LicenseContainer {
    private let asset: ContainerAsset
    private let licensePath: RelativeURL

    init(asset: ContainerAsset, pathInContainer: RelativeURL) {
        self.asset = asset
        licensePath = pathInContainer
    }

    func containsLicense() async throws -> Bool {
        asset.container[licensePath] != nil
    }

    func read() async throws -> Data {
        do {
            guard let resource = asset.container[licensePath] else {
                throw LCPError.licenseContainer(.fileNotFound(licensePath.string))
            }

            return try await resource.read().get()

        } catch {
            throw LCPError.licenseContainer(.readFailed(path: licensePath.string))
        }
    }

    var isWritable: Bool {
        asset.format.conformsTo(.zip) && asset.container.sourceURL?.fileURL != nil
    }

    func write(_ license: LicenseDocument) async throws {
        guard let file = asset.container.sourceURL?.fileURL else {
            throw LCPError.licenseContainer(.writeFailed(path: licensePath.string))
        }

        let archive: Archive
        do {
            archive = try await Archive(url: file.url, accessMode: .update)
        } catch {
            throw LCPError.licenseContainer(.openFailed(error))
        }

        do {
            // Removes the old License if it already exists in the archive, otherwise we get duplicated entries
            if let oldLicense = try await archive.get(licensePath.string) {
                try await archive.remove(oldLicense)
            }

            // Stores the License into the ZIP file
            let data = license.jsonData
            try await archive.addEntry(with: licensePath.string, type: .file, uncompressedSize: Int64(data.count), provider: { position, size -> Data in
                data[position ..< Int64(size)]
            })
        } catch {
            throw LCPError.licenseContainer(.writeFailed(path: licensePath.string))
        }
    }
}
