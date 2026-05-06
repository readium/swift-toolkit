//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP

class InMemoryLCPLicenseRepository: LCPLicenseRepository {
    private var licenses: [LicenseDocument.ID: LicenseDocument] = [:]
    private var registeredDevices: Set<LicenseDocument.ID> = []
    private var rights: [LicenseDocument.ID: LCPConsumableUserRights] = [:]

    func addLicense(_ licenseDocument: LicenseDocument) async throws {
        licenses[licenseDocument.id] = licenseDocument
        if rights[licenseDocument.id] == nil {
            rights[licenseDocument.id] = LCPConsumableUserRights(
                print: licenseDocument.rights.print,
                copy: licenseDocument.rights.copy
            )
        }
    }

    func license(for id: LicenseDocument.ID) async throws -> LicenseDocument? {
        licenses[id]
    }

    func isDeviceRegistered(for id: LicenseDocument.ID) async throws -> Bool {
        registeredDevices.contains(id)
    }

    func registerDevice(for id: LicenseDocument.ID) async throws {
        registeredDevices.insert(id)
    }

    func userRights(for id: LicenseDocument.ID) async throws -> LCPConsumableUserRights {
        rights[id] ?? LCPConsumableUserRights(print: nil, copy: nil)
    }

    func updateUserRights(
        for id: LicenseDocument.ID,
        with changes: (inout LCPConsumableUserRights) -> Void
    ) async throws {
        var current = rights[id] ?? LCPConsumableUserRights(print: nil, copy: nil)
        changes(&current)
        rights[id] = current
    }
}
