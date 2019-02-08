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

}

extension Licenses: LicensesRepository {
    
    func addOrUpdateLicense(_ license: LicenseDocument) throws {
        let db = Database.shared.connection
        
        let filterLicense = licenses.filter(id == license.id)
        let exists = try db.scalar(filterLicense.count) != 0
        if !exists {
            let query = licenses.insert(
                id <- license.id,
                printsLeft <- license.rights.print,
                copiesLeft <- license.rights.copy,
                provider <- license.provider.absoluteString,
                issued <- license.issued,
                updated <- license.dateOfLastUpdate(),
                end <- license.rights.end,
                state <- nil
            )
            try db.run(query)

        } else {
            let query = filterLicense.update(
                provider <- license.provider.absoluteString,
                issued <- license.issued,
                updated <- license.dateOfLastUpdate(),
                end <- license.rights.end
            )
            try db.run(query)
        }
    }
    
    func updateLicenseStatus(_ license: LicenseDocument, to status: StatusDocument) throws {
        let db = Database.shared.connection
        let query = licenses
            .filter(id == license.id)
            .update(state <- status.status.rawValue)
        try db.run(query)
    }

}

extension Licenses: DeviceRepository {
    
    func isDeviceRegistered(for license: LicenseDocument) throws -> Bool {
        let db = Database.shared.connection
        let query = licenses.filter(id == license.id && registered == true)
        let count = try db.scalar(query.count)
        return count != 0
    }
    
    func registerDevice(for license: LicenseDocument) throws {
        let db = Database.shared.connection
        let filterLicense = licenses.filter(id == license.id)
        try db.run(filterLicense.update(registered <- true))
    }

}
