//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents an LCP passphrase hash.
public typealias LCPPassphraseHash = String

/// The passphrase repository stores passphrase hashes, optionally associated
/// with a user ID and provider.
public protocol LCPPassphraseRepository {
    /// Returns a list of passphrase hashes that may match the given `userID`
    /// and `provider`.
    func passphrasesMatching(
        userID: User.ID?,
        provider: LicenseDocument.Provider
    ) async throws -> [LCPPassphraseHash]

    /// Returns all the saved passphrase hashes.
    func passphrases() async throws -> [LCPPassphraseHash]

    /// Adds a new passphrase hash to the repository.
    ///
    /// If the same passphrase hash is already stored, its `userID` and
    /// `provider` are updated.
    func addPassphrase(
        _ hash: LCPPassphraseHash,
        userID: User.ID?,
        provider: LicenseDocument.Provider?
    ) async throws
}

public extension LCPPassphraseRepository {
    /// Adds the passphrase `hash` associated with the given `license`.
    func addPassphrase(_ hash: LCPPassphraseHash, for license: LicenseDocument) async throws {
        try await addPassphrase(hash, userID: license.user.id, provider: license.provider)
    }

    /// Adds a passphrase `hash` without any associated user or provider.
    func addPassphrase(_ hash: LCPPassphraseHash) async throws {
        try await addPassphrase(hash, userID: nil, provider: nil)
    }
}
