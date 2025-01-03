//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents an LCP passphrase hash.
public typealias LCPPassphraseHash = String

/// The passphrase repository stores passphrase hashes associated to a license document, user ID and
/// provider.
public protocol LCPPassphraseRepository {
    /// Returns the passphrase hash associated with the given `licenseID`.
    func passphrase(for licenseID: LicenseDocument.ID) async throws -> LCPPassphraseHash?

    /// Returns a list of passphrase hashes that may match the given `userID`, and `provider`.
    func passphrasesMatching(
        userID: User.ID?,
        provider: LicenseDocument.Provider
    ) async throws -> [LCPPassphraseHash]

    /// Adds a new passphrase hash to the repository.
    ///
    /// If a passphrase is already associated with the given `licenseID`, it will be updated.
    func addPassphrase(
        _ hash: LCPPassphraseHash,
        for licenseID: LicenseDocument.ID,
        userID: User.ID?,
        provider: LicenseDocument.Provider
    ) async throws
}

public extension LCPPassphraseRepository {
    func addPassphrase(_ hash: LCPPassphraseHash, for license: LicenseDocument) async throws {
        try await addPassphrase(hash, for: license.id, userID: license.user.id, provider: license.provider)
    }
}
