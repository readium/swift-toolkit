//
//  Transactions.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 10/2/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SQLite

/// Database's TransactionsTable , in charge of keeping tracks of
/// the previous license checking.
class Transactions {
    let databaseUrl: URL!
    /// Table.
    let transactions = Table("Transactions")
    /// Fields.
    let licenseId = Expression<Int>("licenseId")
    let origin = Expression<String>("origin")
    let passphrase = Expression<String>("passphrase") // hashed

    init(forDatabaseAt url: URL) throws {
        let database = try Connection(url.absoluteString)
//
        databaseUrl = url
        do {
            try database.run(transactions.create(temporary: false, ifNotExists: true) { t in
                t.column(licenseId)
                t.column(origin)
                t.column(passphrase)
            })
        } catch {
            print(error.localizedDescription)
        }
    }
}
