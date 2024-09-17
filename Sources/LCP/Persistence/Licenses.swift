//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SQLite

/// Database's Licenses table, in charge of keeping tracks of the
/// licenses attributed to each books and the associated rights.
class Licenses {
    /// Table.
    let licenses = Table("Licenses")
    /// Fields.
    let id = SQLite.Expression<String>("id")
    let printsLeft = SQLite.Expression<Int?>("printsLeft")
    let copiesLeft = SQLite.Expression<Int?>("copiesLeft")
    let registered = SQLite.Expression<Bool>("registered")

    init(_ connection: Connection) {
        _ = try? connection.run(licenses.create(temporary: false, ifNotExists: true) { t in
            t.column(id, unique: true)
            t.column(printsLeft)
            t.column(copiesLeft)
        })

        if connection.userVersion == 0 {
            _ = try? connection.run(licenses.addColumn(registered, defaultValue: false))
            connection.userVersion = 1
        }
        if connection.userVersion == 1 {
            // This migration is empty because it got deprecated...
            connection.userVersion = 2
        }
    }

    private func exists(_ license: LicenseDocument) -> Bool {
        let db = Database.shared.connection
        let filterLicense = licenses.filter(id == license.id)
        return ((try? db.count(filterLicense)) ?? 0) != 0
    }

    private func get(_ column: SQLite.Expression<Int?>, for licenseId: String) throws -> Int? {
        let db = Database.shared.connection
        let query = licenses.select(column).filter(id == licenseId)
        for row in try db.prepare(query) {
            return try row.get(column)
        }
        return nil
    }

    private func set(_ column: SQLite.Expression<Int?>, to value: Int, for licenseId: String) throws {
        let db = Database.shared.connection
        let filterLicense = licenses.filter(id == licenseId)
        try db.run(filterLicense.update(column <- value))
    }
}

extension Licenses: LicensesRepository {
    func addLicense(_ license: LicenseDocument) throws {
        let db = Database.shared.connection
        guard !exists(license) else {
            return
        }

        let query = licenses.insert(
            id <- license.id,
            printsLeft <- license.rights.print,
            copiesLeft <- license.rights.copy
        )
        try db.run(query)
    }

    func copiesLeft(for licenseId: String) throws -> Int? {
        try get(copiesLeft, for: licenseId)
    }

    func setCopiesLeft(_ quantity: Int, for licenseId: String) throws {
        try set(copiesLeft, to: quantity, for: licenseId)
    }

    func printsLeft(for licenseId: String) throws -> Int? {
        try get(printsLeft, for: licenseId)
    }

    func setPrintsLeft(_ quantity: Int, for licenseId: String) throws {
        try set(printsLeft, to: quantity, for: licenseId)
    }
}

extension Licenses: DeviceRepository {
    func isDeviceRegistered(for license: LicenseDocument) throws -> Bool {
        guard exists(license) else {
            throw LCPError.runtime("The LCP License doesn't exist in the database")
        }

        let db = Database.shared.connection
        let query = licenses.filter(id == license.id && registered == true)
        let count = try db.count(query)
        return count != 0
    }

    func registerDevice(for license: LicenseDocument) throws {
        guard exists(license) else {
            throw LCPError.runtime("The LCP License doesn't exist in the database")
        }

        let db = Database.shared.connection
        let filterLicense = licenses.filter(id == license.id)
        try db.run(filterLicense.update(registered <- true))
    }
}
