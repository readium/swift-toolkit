//
//  ZIPLicenseContainer.swift
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
/// Meant to be subclassed to customize the pathInZIP property, eg. EPUBLicenseContainer.
class ZIPLicenseContainer: LicenseContainer {
    
    private let zip: URL
    private let pathInZIP: String
    
    init(zip: URL, pathInZIP: String) {
        self.zip = zip
        self.pathInZIP = pathInZIP
    }
    
    func read() throws -> Data {
        guard let archive = Archive(url: zip, accessMode: .read) else  {
            throw LCPError.container
        }
        guard let entry = archive[pathInZIP] else {
            throw LCPError.licenseNotInContainer
        }
        
        var data = Data()
        do {
            _ = try archive.extract(entry) { part in
                data.append(part)
            }
        } catch {
            throw LCPError.container
        }

        return data
    }
    
    func write(_ license: LicenseDocument) throws {
        guard let archive = Archive(url: zip, accessMode: .update) else  {
            throw LCPError.container
        }

        do {
            // Removes the old License if it already exists in the archive, otherwise we get duplicated entries
            if let oldLicense = archive[pathInZIP] {
                try archive.remove(oldLicense)
            }

            // Stores the License into the ZIP file
            let data = license.data
            try archive.addEntry(with: pathInZIP, type: .file, uncompressedSize: UInt32(data.count), provider: { (position, size) -> Data in
                return data[position..<size]
            })
        } catch {
            throw LCPError.container
        }
    }
    
}
