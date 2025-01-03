//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import ReadiumZIPFoundation

/// Access to a License Document stored in a ZIP archive.
/// Meant to be subclassed to customize the pathInZIP property, eg. EPUBLicenseContainer.
class ZIPLicenseContainer: LicenseContainer {
    private let zip: FileURL
    private let pathInZIP: String

    init(zip: FileURL, pathInZIP: String) {
        self.zip = zip
        self.pathInZIP = pathInZIP
    }

    func containsLicense() async throws -> Bool {
        do {
            let archive = try Archive(url: zip.url, accessMode: .read)
            return archive[pathInZIP] != nil
        } catch {
            throw LCPError.licenseContainer(.openFailed(error))
        }
    }

    func read() async throws -> Data {
        let archive: Archive
        do {
            archive = try Archive(url: zip.url, accessMode: .read)
        } catch {
            throw LCPError.licenseContainer(.openFailed(error))
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

    func write(_ license: LicenseDocument) async throws {
        let archive: Archive
        do {
            archive = try Archive(url: zip.url, accessMode: .update)
        } catch {
            throw LCPError.licenseContainer(.openFailed(error))
        }

        do {
            // Removes the old License if it already exists in the archive, otherwise we get duplicated entries
            if let oldLicense = archive[pathInZIP] {
                try archive.remove(oldLicense)
            }

            // Stores the License into the ZIP file
            let data = license.jsonData
            try archive.addEntry(with: pathInZIP, type: .file, uncompressedSize: Int64(data.count), provider: { position, size -> Data in
                data[position ..< Int64(size)]
            })
        } catch {
            throw LCPError.licenseContainer(.writeFailed(path: pathInZIP))
        }
    }
}
