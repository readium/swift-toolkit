//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumLCP
import ReadiumShared
import SQLite

public class LCPSQLitePassphraseRepository: LCPPassphraseRepository, Loggable {
    let transactions = Table("Transactions")
    let licenseId = SQLite.Expression<String>("licenseId")
    let provider = SQLite.Expression<String>("origin")
    let userId = SQLite.Expression<String?>("userId")
    let passphrase = SQLite.Expression<String>("passphrase") // hashed.

    private let db: Connection

    public init() throws {
        db = try Database.shared.get().connection

        try db.run(transactions.create(temporary: false, ifNotExists: true) { t in
            t.column(licenseId)
            t.column(provider)
            t.column(userId)
            t.column(passphrase)
        })
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
            var passphrases =
                try db.prepare(transactions.select(passphrase)
                        .filter(self.userId == userID && self.provider == provider)
                    )
                    .compactMap { try $0.get(passphrase) }

            // The legacy SQLite database did not save all the new
            // (passphrase, userID, provider) tuples. So we need to fall back
            // on checking all the saved passphrases for a match.
            passphrases += try db.prepare(transactions.select(passphrase))
                .compactMap { try $0.get(passphrase) }

            return passphrases
        }
    }

    public func passphrases() async throws -> [LCPPassphraseHash] {
        try logAndRethrow {
            try db.prepare(transactions.select(passphrase))
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

    /// Migrates all passphrases from this SQLite repository to the target
    /// repository.
    ///
    /// - Returns: `true` if all the passphrases were migrated successfully.
    @discardableResult
    public func migrate(to target: LCPPassphraseRepository) async throws -> Bool {
        let allPassphraseData = try db.prepare(transactions).map { row in
            try (
                licenseId: row.get(licenseId),
                passphrase: row.get(passphrase),
                provider: row.get(provider),
                userId: row.get(userId)
            )
        }

        var successCount = 0
        var failureCount = 0

        for passphraseData in allPassphraseData {
            do {
                try await target.addPassphrase(
                    passphraseData.passphrase,
                    for: passphraseData.licenseId,
                    userID: passphraseData.userId,
                    provider: passphraseData.provider
                )
                successCount += 1
            } catch {
                failureCount += 1
                // Log error but continue with other passphrases
                log(.error, "Failed to migrate passphrase for license \(passphraseData.licenseId): \(error)")
            }
        }

        if failureCount > 0 {
            log(.info, "Passphrase migration completed with \(successCount) succeeded, \(failureCount) failed")
        } else {
            log(.info, "Passphrase migration completed successfully: \(successCount) passphrases migrated")
        }

        return failureCount == 0
    }
}
