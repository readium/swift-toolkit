//
//  Licenses.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 10/2/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SQLite

/// Database's Licenses table, in charge of keeping tracks of the
/// licenses attributed to each books and the associated rights.
class Licenses {
    let databaseUrl: URL!
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

    init(forDatabaseAt url: URL) throws {
        let database = try Connection(url.absoluteString)

        self.databaseUrl = url
        do {
            try database.run(licenses.create(temporary: false, ifNotExists: true) { t in
                t.column(id, unique: true)
                t.column(printsLeft)
                t.column(copiesLeft)
                t.column(provider)
                t.column(issued)
                t.column(updated)
                t.column(end)
                t.column(state)
            })
        } catch {
            print(error.localizedDescription)
        }
    }

    /// Check if the table already contains an entry for the given ID.
    ///
    /// - Parameter id: The ID to check for.
    /// - Returns: A boolean indicating the result of the search, true if found.
    /// - Throws: .
    internal func existingLicense(with id: String) throws -> Bool {
        let database = try Connection(databaseUrl.absoluteString)
        // Check if empty.
        guard try database.scalar(licenses.count) > 0 else {
            return false
        }
        let query = licenses.filter(self.id == id)
        let count = try database.scalar(query.count)
        return count == 1
        return false
    }

    /// Add a registered license to the database.
    ///
    /// - Parameters:
    ///   - license: <#license description#>
    ///   - status: <#status description#>
    /// - Throws: <#throws value description#>
    internal func insert(_ license: LicenseDocument, with status: StatusDocument.Status?) throws {
        let database = try Connection(databaseUrl.absoluteString)
        let insertQuery = licenses.insert(
            id <- license.id,
            printsLeft <- license.rights.print,
            copiesLeft <- license.rights.copy,
            provider <- license.provider.absoluteString,
            issued <- license.issued,
            updated <- license.updated,
            end <- license.rights.end,
            state <- status?.rawValue ?? nil
        )
        try database.run(insertQuery)
    }
    
}
