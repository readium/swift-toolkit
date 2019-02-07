//
//  ZipLicenseContainer.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 05.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import ZIPFoundation

/// Access to a License Document stored in a ZIP archive.
/// Meant to be subclassed to customize the pathInZip property, eg. EpubLicenseContainer.
class ZipLicenseContainer: LicenseContainer {
    
    private let zip: URL
    private let pathInZip: String
    
    init(zip: URL, pathInZip: String) {
        self.zip = zip
        self.pathInZip = pathInZip
    }
    
    func read() throws -> Data {
        guard let archive = Archive(url: zip, accessMode: .read) else  {
            throw LcpError.container
        }
        guard let entry = archive[pathInZip] else {
            throw LcpError.licenseNotInContainer
        }
        
        var data = Data()
        do {
            _ = try archive.extract(entry) { part in
                data.append(part)
            }
        } catch {
            throw LcpError.container
        }

        return data
    }
    
    func write(_ license: LicenseDocument) throws {
        guard let archive = Archive(url: zip, accessMode: .update) else  {
            throw LcpError.container
        }
        guard let data = license.json.data(using: .utf8) else {
            throw LcpError.invalidJson
        }
        
        do {
            // Removes the old License if it already exists in the archive, otherwise we get duplicated entries
            if let oldLicense = archive[pathInZip] {
                try archive.remove(oldLicense)
            }

            // Stores the License into the ZIP file
            try archive.addEntry(with: pathInZip, type: .file, uncompressedSize: UInt32(data.count), provider: { (position, size) -> Data in
                return data[position..<size]
            })
        } catch {
            throw LcpError.container
        }
    }
    
}
