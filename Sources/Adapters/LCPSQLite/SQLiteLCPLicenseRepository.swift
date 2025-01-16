//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumLCP
import SQLite

public class LCPSQLiteLicenseRepository: LCPLicenseRepository {
    let licenses = Table("Licenses")
    let id = SQLite.Expression<String>("id")
    let printsLeft = SQLite.Expression<Int?>("printsLeft")
    let copiesLeft = SQLite.Expression<Int?>("copiesLeft")
    let registered = SQLite.Expression<Bool>("registered")

    private let db: Connection

    public init() throws {
        db = try Database.shared.get().connection

        try db.run(licenses.create(temporary: false, ifNotExists: true) { t in
            t.column(id, unique: true)
            t.column(printsLeft)
            t.column(copiesLeft)
        })

        if db.userVersion == 0 {
            try db.run(licenses.addColumn(registered, defaultValue: false))
            db.userVersion = 1
        }
        if db.userVersion == 1 {
            // This migration is empty because it got deprecated...
            db.userVersion = 2
        }
    }

    public func addLicense(_ licenseDocument: LicenseDocument) async throws {
        guard !exists(licenseDocument.id) else {
            return
        }

        let query = licenses.insert(
            id <- licenseDocument.id,
            printsLeft <- licenseDocument.rights.print,
            copiesLeft <- licenseDocument.rights.copy
        )
        try db.run(query)
    }

    public func license(for id: LicenseDocument.ID) async throws -> LicenseDocument? {
        // Note: this was not implemented with the legacy SQLite repository, so
        // we don't have the license in the database.
        nil
    }

    public func isDeviceRegistered(for id: LicenseDocument.ID) async throws -> Bool {
        try checkExists(id)
        let count = try db.scalar(licenses.filter(self.id == id && registered == true).count)
        return count != 0
    }

    public func registerDevice(for id: LicenseDocument.ID) async throws {
        try checkExists(id)
        let filterLicense = licenses.filter(self.id == id)
        try db.run(filterLicense.update(registered <- true))
    }

    public func userRights(for id: LicenseDocument.ID) async throws -> LCPConsumableUserRights {
        try getRights(for: id)
    }

    public func updateUserRights(for id: LicenseDocument.ID, with changes: (inout LCPConsumableUserRights) -> Void) async throws {
        try db.transaction {
            let rights = try getRights(for: id)

            var newRights = rights
            changes(&newRights)

            if rights.copy != newRights.copy {
                try set(copiesLeft, to: newRights.copy, for: id)
            }

            if rights.print != newRights.print {
                try set(printsLeft, to: newRights.print, for: id)
            }
        }
    }

    private func checkExists(_ licenseID: LicenseDocument.ID) throws {
        guard exists(licenseID) else {
            throw LCPError.runtime("The LCP License doesn't exist in the database")
        }
    }

    private func exists(_ licenseID: LicenseDocument.ID) -> Bool {
        ((try? db.scalar(licenses.filter(id == licenseID).count)) ?? 0) != 0
    }

    private func get(_ column: SQLite.Expression<Int?>, for licenseId: String) throws -> Int? {
        let query = licenses.select(column).filter(id == licenseId)
        for row in try db.prepare(query) {
            return try row.get(column)
        }
        return nil
    }

    private func set(_ column: SQLite.Expression<Int?>, to value: Int?, for licenseId: String) throws {
        let filterLicense = licenses.filter(id == licenseId)
        try db.run(filterLicense.update(column <- value))
    }

    private func getRights(for id: LicenseDocument.ID) throws -> LCPConsumableUserRights {
        try LCPConsumableUserRights(
            print: get(printsLeft, for: id),
            copy: get(copiesLeft, for: id)
        )
    }
}
