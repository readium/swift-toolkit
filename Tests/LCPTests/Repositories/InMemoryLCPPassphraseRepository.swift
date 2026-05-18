//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP

class InMemoryLCPPassphraseRepository: LCPPassphraseRepository {
    private struct Entry {
        var hash: LCPPassphraseHash
        var userID: User.ID?
        var provider: LicenseDocument.Provider
    }

    private var entries: [LicenseDocument.ID: Entry] = [:]

    func passphrase(for licenseID: LicenseDocument.ID) async throws -> LCPPassphraseHash? {
        entries[licenseID]?.hash
    }

    func passphrasesMatching(userID: User.ID?, provider: LicenseDocument.Provider) async throws -> [LCPPassphraseHash] {
        entries.values.compactMap { entry in
            guard entry.provider == provider else { return nil }
            if let userID { return entry.userID == userID ? entry.hash : nil }
            return entry.hash
        }
    }

    func passphrases() async throws -> [LCPPassphraseHash] {
        entries.values.map(\.hash)
    }

    func addPassphrase(
        _ hash: LCPPassphraseHash,
        for licenseID: LicenseDocument.ID,
        userID: User.ID?,
        provider: LicenseDocument.Provider
    ) async throws {
        entries[licenseID] = Entry(hash: hash, userID: userID, provider: provider)
    }
}
