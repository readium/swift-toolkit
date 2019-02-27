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
    let registered = Expression<Bool>("registered")
    
    init(_ connection: Connection) {
        
        _ = try? connection.run(licenses.create(temporary: false, ifNotExists: true) { t in
            t.column(id, unique: true)
            t.column(printsLeft)
            t.column(copiesLeft)
        })
        
        if 0 == connection.userVersion {
            _ = try? connection.run(licenses.addColumn(registered, defaultValue: false))
            connection.userVersion = 1
        }
        if 1 == connection.userVersion {
            // This migration is empty because it got deprecated...
            connection.userVersion = 2
        }
    }
    
    private func exists(_ license: LicenseDocument) -> Bool {
        let db = Database.shared.connection
        let filterLicense = licenses.filter(id == license.id)
        return ((try? db.scalar(filterLicense.count)) ?? 0) != 0
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

}

extension Licenses: DeviceRepository {
    
    func isDeviceRegistered(for license: LicenseDocument) throws -> Bool {
        guard exists(license) else {
            throw LCPError.runtime("The LCP License doesn't exist in the database")
        }
        
        let db = Database.shared.connection
        let query = licenses.filter(id == license.id && registered == true)
        let count = try db.scalar(query.count)
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
