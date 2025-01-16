//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Access to a License Document packaged as a standalone LCPL file.
final class LCPLLicenseContainer: LicenseContainer {
    private let lcpl: FileURL

    init(lcpl: FileURL) {
        self.lcpl = lcpl
    }

    func containsLicense() async throws -> Bool {
        true
    }

    func read() async throws -> Data {
        guard let data = try? Data(contentsOf: lcpl.url) else {
            throw LCPError.licenseContainer(.readFailed(path: "."))
        }
        return data
    }

    func write(_ license: LicenseDocument) async throws {
        do {
            try license.jsonData.write(to: lcpl.url, options: .atomic)
        } catch {
            throw LCPError.licenseContainer(.writeFailed(path: "."))
        }
    }
}
