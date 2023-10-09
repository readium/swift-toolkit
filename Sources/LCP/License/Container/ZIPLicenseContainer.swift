//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ZIPFoundation

/// Access to a License Document stored in a ZIP archive.
/// Meant to be subclassed to customize the pathInZIP property, eg. EPUBLicenseContainer.
class ZIPLicenseContainer: LicenseContainer {
    private let zip: URL
    private let pathInZIP: String

    init(zip: URL, pathInZIP: String) {
        self.zip = zip
        self.pathInZIP = pathInZIP
    }

    func containsLicense() -> Bool {
        guard let archive = Archive(url: zip, accessMode: .read) else {
            return false
        }
        return archive[pathInZIP] != nil
    }

    func read() throws -> Data {
        guard let archive = Archive(url: zip, accessMode: .read) else {
            throw LCPError.licenseContainer(.openFailed)
        }
        guard let entry = archive[pathInZIP] else {
            throw LCPError.licenseContainer(.fileNotFound(pathInZIP))
        }

        var data = Data()
        do {
            _ = try archive.extract(entry) { part in
                data.append(part)
            }
        } catch {
            throw LCPError.licenseContainer(.readFailed(path: pathInZIP))
        }

        return data
    }

    func write(_ license: LicenseDocument) throws {
        guard let archive = Archive(url: zip, accessMode: .update) else {
            throw LCPError.licenseContainer(.openFailed)
        }

        do {
            // Removes the old License if it already exists in the archive, otherwise we get duplicated entries
            if let oldLicense = archive[pathInZIP] {
                try archive.remove(oldLicense)
            }

            // Stores the License into the ZIP file
            let data = license.data
            try archive.addEntry(with: pathInZIP, type: .file, uncompressedSize: UInt32(data.count), provider: { position, size -> Data in
                data[position ..< size]
            })
        } catch {
            throw LCPError.licenseContainer(.writeFailed(path: pathInZIP))
        }
    }
}
