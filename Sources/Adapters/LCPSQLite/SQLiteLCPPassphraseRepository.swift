//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumLCP
import ReadiumShared
import SQLite

public class LCPSQLitePassphraseRepository: LCPPassphraseRepository, Loggable {
    let transactions = Table("Transactions")
    let licenseId = Expression<String>("licenseId")
    let provider = Expression<String>("origin")
    let userId = Expression<String?>("userId")
    let passphrase = Expression<String>("passphrase") // hashed.

    private let db: Connection

    public init() {
        db = Database.shared.connection

        do {
            try db.run(transactions.create(temporary: false, ifNotExists: true) { t in
                t.column(licenseId)
                t.column(provider)
                t.column(userId)
                t.column(passphrase)
            })
        } catch {
            log(.error, error)
        }
    }

    public func passphrase(for licenseID: LicenseDocument.ID) async throws -> LCPPassphraseHash? {
        try logAndRethrow {
            try db.prepare(transactions.select(passphrase)
                .filter(self.licenseId == licenseID)
            )
            .compactMap { try $0.get(passphrase) }
            .first
        }
    }

    public func passphrasesMatching(userID: User.ID?, provider: LicenseDocument.Provider) async throws -> [LCPPassphraseHash] {
        try logAndRethrow {
            try db.prepare(transactions.select(passphrase)
                .filter(self.userId == userID && self.provider == provider)
            )
            .compactMap { try $0.get(passphrase) }
        }
    }

    public func addPassphrase(_ hash: LCPPassphraseHash, for licenseID: LicenseDocument.ID, userID: User.ID?, provider: LicenseDocument.Provider) async throws {
        try logAndRethrow {
            try db.run(
                transactions.insert(
                    or: .replace,
                    self.passphrase <- hash,
                    self.licenseId <- licenseID,
                    self.provider <- provider,
                    self.userId <- userID
                )
            )
        }
    }

    private func all() -> [String] {
        let query = transactions.select(passphrase)
        do {
            return try db.prepare(query).compactMap { try $0.get(passphrase) }
        } catch {
            log(.error, error)
            return []
        }
    }
}
