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
    let licenseId = Expression<String>("licenseId")
    let origin = Expression<String>("origin")
    let passphrase = Expression<String>("passphrase") // hashed.
    
    init(_ connection: Connection)  {
        _ = try? connection.run(transactions.create(temporary: false, ifNotExists: true) { t in
            t.column(licenseId)
            t.column(origin)
            t.column(passphrase)
        })
    }

    func add(_ licenseId: String, _ origin: String, _ passphrase: String) throws {
        let db = LCPDatabase.shared.connection

        let insertQuery = transactions.insert(
            self.licenseId <- licenseId,
            self.origin <- origin,
            self.passphrase <- passphrase
        )
        try db.run(insertQuery)
    }

    /// Try to find the possible passphrases for the license/provider tuple.
    ///
    /// - Parameters:
    ///   - licenseId: <#licenseId description#>
    ///   - provider: <#provider description#>
    /// - Returns: <#return value description#>
    func possiblePassphrases(for licenseId: String, and provider: URL) throws -> [String] {
        var possiblePassphrases = [String]()
        let licensePassphrase: String?
        let providerPassphrases: [String]

        licensePassphrase = try passphrase(for: licenseId)
        providerPassphrases = try passphrases(for: provider)
        if let licensePassphrase = licensePassphrase {
            possiblePassphrases.append(licensePassphrase)
        }
        possiblePassphrases.append(contentsOf: providerPassphrases)
        return possiblePassphrases
    }

    /// Returns the passphrase found for given license.
    ///
    /// - Parameter id: <#id description#>
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    func passphrase(for license: String) throws -> String? {
        let db = LCPDatabase.shared.connection
        let query = transactions.select(passphrase).filter(licenseId == license)

        for row in try db.prepare(query) {
            return try row.get(passphrase)
        }
        return nil
    }

    /// Return a passphrases array found for the given provider.
    ///
    /// - Parameter provider: The book provider URL.
    /// - Returns: The passhrases found in DB for the given provider.
    func passphrases(for provider: URL) throws -> [String] {
        let db = LCPDatabase.shared.connection
        let query = transactions.select(passphrase).filter(origin == provider.absoluteString)

        return try db.prepare(query).flatMap({ try? $0.get(passphrase) })
    }
}
