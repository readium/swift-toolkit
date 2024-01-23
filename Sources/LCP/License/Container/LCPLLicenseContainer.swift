//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Access to a License Document packaged as a standalone LCPL file.
final class LCPLLicenseContainer: LicenseContainer {
    private let lcpl: URL

    init(lcpl: URL) {
        self.lcpl = lcpl
    }

    func containsLicense() -> Bool {
        true
    }

    func read() throws -> Data {
        guard let data = try? Data(contentsOf: lcpl) else {
            throw LCPError.licenseContainer(.readFailed(path: "."))
        }
        return data
    }

    func write(_ license: LicenseDocument) throws {
        do {
            try license.data.write(to: lcpl, options: .atomic)
        } catch {
            throw LCPError.licenseContainer(.writeFailed(path: "."))
        }
    }
}
