//
//  Licenses.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 10/2/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SQLite

/// Database's Licenses table, in charge of keeping tracks of the
/// licenses attributed to each books and the associated rights.
class Licenses {
    /// Table.
    let licenses = Table("Licenses")
    /// Fields.
    let id = Expression<String>("id")
    let printsLeft = Expression<Int?>("printsLeft")
    let copiesLeft = Expression<Int?>("copiesLeft")
    let provider = Expression<String>("provider")
    let issued = Expression<Date>("issued")
    let updated = Expression<Date?>("updated")
    let end = Expression<Date?>("end")
    let state = Expression<String?>("state")
    
    let registered = Expression<Bool>("registered")
    
    init(_ connection: Connection) {
        
        _ = try? connection.run(licenses.create(temporary: false, ifNotExists: true) { t in
            t.column(id, unique: true)
            t.column(printsLeft)
            t.column(copiesLeft)
            t.column(provider)
            t.column(issued)
            t.column(updated)
            t.column(end)
            t.column(state)
        })
        
        if 0 == connection.userVersion {
            _ = try? connection.run(licenses.addColumn(registered, defaultValue: false))
            connection.userVersion = 1
        }
        if 1 == connection.userVersion {
            // DEPRECATED: We don't use those columns anymore
//            _ = try? connection.run(licenses.addColumn(localFileURL))
//            _ = try? connection.run(licenses.addColumn(localFileUpdated))
            connection.userVersion = 2
        }
    }

    internal func dateOfLastUpdate(forLicenseWith id: String) -> Date? {
        let db = LcpDatabase.shared.connection
        let query = licenses.filter(self.id == id).select(updated).order(updated.desc)

        do {
            for result in try db.prepare(query) {
                do {
                    return try result.get(updated)
                } catch {
                    return nil
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    internal func updateState(forLicenseWith id: String, to state: String) throws {
        let db = LcpDatabase.shared.connection
        let license = licenses.filter(self.id == id)

        // Check if empty.
        guard try db.scalar(license.count) > 0 else {
            throw LcpError.licenseNotFound
        }
        try db.run(license.update(self.state <- state))
    }

    /// Check if the table already contains an entry for the given ID.
    ///
    /// - Parameter id: The ID to check for.
    /// - Returns: A boolean indicating the result of the search, true if found.
    /// - Throws: .
    internal func existingLicense(with id: String) throws -> Bool {
        let db = LcpDatabase.shared.connection
        // Check if empty.
        guard try db.scalar(licenses.count) > 0 else {
            return false
        }
        let query = licenses.filter(self.id == id)
        let count = try db.scalar(query.count)

        return count == 1
    }

    /// Delete the database item info for a given licenseID
    ///
    /// - Parameter licenseID: The ID to check.
    /// - Throws: .
    internal func deleteData(for licenseID: String) throws -> Void {
        
        let db = LcpDatabase.shared.connection
        let license = licenses.filter(self.id == id)
        
        // Check if empty.
        guard try db.scalar(license.count) > 0 else {
            throw LcpError.licenseNotFound
        }
        
        try db.run(license.delete())
    }

    /// Add a registered license to the database.
    ///
    /// - Parameters:
    ///   - license: <#license description#>
    ///   - status: <#status description#>
    /// - Throws: <#throws value description#>
    internal func insert(_ license: LicenseDocument, with status: StatusDocument.Status?) throws {
        let db = LcpDatabase.shared.connection

        let insertQuery = licenses.insert(
            id <- license.id,
            printsLeft <- license.rights.print,
            copiesLeft <- license.rights.copy,
            provider <- license.provider.absoluteString,
            issued <- license.issued,
            updated <- license.updated,
            end <- license.rights.end,
            state <- status?.rawValue ?? nil,
            registered <- false
        )
        
        try db.run(insertQuery)
    }
    
}

extension Licenses: DeviceRepository {
    
    func isDeviceRegistered(for license: LicenseDocument) throws -> Bool {
        let db = LcpDatabase.shared.connection
        let query = licenses.filter(self.id == license.id && self.registered == true)
        let count = try db.scalar(query.count)
        return count == 1
    }
    
    func registerDevice(for license: LicenseDocument) throws {
        let db = LcpDatabase.shared.connection
        let license = licenses.filter(self.id == id)
        try db.run(license.update(self.registered <- true))
    }

}
