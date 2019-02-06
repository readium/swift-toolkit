//
//  LcplLicenseContainer.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 05.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Access to a License Document packaged as a standalone LCPL file.
final class LcplLicenseContainer: LicenseContainer {
    
    private let lcpl: URL
    
    init(lcpl: URL) {
        self.lcpl = lcpl
    }
    
    func read() throws -> LicenseDocument {
        guard let data = try? Data(contentsOf: lcpl) else {
            throw LcpError.container
        }
        guard let license = try? LicenseDocument(with: data) else {
            throw LcpError.invalidLcpl
        }
        
        return license
    }
    
    func write(_ license: LicenseDocument) throws {
        do {
            try license.json.write(to: lcpl, atomically: true, encoding: .utf8)
        } catch {
            throw LcpError.container
        }
    }

}
