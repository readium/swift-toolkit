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
    /// Table.
    let transactions = Table("Transactions")
    /// Fields.
    let licenseId = Expression<Int>("licenseId")
    let origin = Expression<String>("origin")
    let passphrase = Expression<String>("passphrase") // hashed
    
    init()  {
        let db = LCPDatabase.shared.connection
        
        _ = try? db.run(transactions.create(temporary: false, ifNotExists: true) { t in
            t.column(licenseId)
            t.column(origin)
            t.column(passphrase)
        })
    }

    /// Returns the passphrase found for given license.
    ///
    /// - Parameter id: <#id description#>
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    func passphrase(forLicense id: String) throws -> String? {
        let db = LCPDatabase.shared.connection
        let query = transactions.select(passphrase).filter(licenseId == Int(id)!)

        for row in try db.prepare(query) {
            return try row.get(passphrase)
        }
        return nil
    }


    /// Retursn a passphrases array found for
    ///
    /// - Parameter provider: <#provider description#>
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    func passphrases(forProvider provider: URL) throws -> [String] {
        let db = LCPDatabase.shared.connection
        let query = transactions.select(passphrase).filter(origin == provider.absoluteString)

        return try db.prepare(query).flatMap({ try? $0.get(passphrase) })
    }
}
