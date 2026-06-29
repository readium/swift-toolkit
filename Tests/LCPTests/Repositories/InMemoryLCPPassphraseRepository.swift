//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP

actor InMemoryLCPPassphraseRepository: LCPPassphraseRepository {
    private struct Entry {
        var userID: User.ID?
        var provider: LicenseDocument.Provider?
    }

    private var entries: [LCPPassphraseHash: Entry] = [:]

    func passphrasesMatching(userID: User.ID?, provider: LicenseDocument.Provider) async throws -> [LCPPassphraseHash] {
        entries.compactMap { hash, entry in
            guard entry.provider == provider else { return nil }
            if let userID { return entry.userID == userID ? hash : nil }
            return hash
        }
    }

    func passphrases() async throws -> [LCPPassphraseHash] {
        Array(entries.keys)
    }

    func addPassphrase(
        _ hash: LCPPassphraseHash,
        userID: User.ID?,
        provider: LicenseDocument.Provider?
    ) async throws {
        entries[hash] = Entry(userID: userID, provider: provider)
    }
}
