//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CryptoSwift
import Foundation
import ReadiumInternal
import ReadiumShared

final class PassphrasesService: Loggable {
    private let client: LCPClient
    private let repository: LCPPassphraseRepository

    private let sha256Predicate = NSPredicate(format: "SELF MATCHES[c] %@", "^([a-f0-9]{64})$")

    init(client: LCPClient, repository: LCPPassphraseRepository) {
        self.client = client
        self.repository = repository
    }

    /// Stores a passphrase in the repository as a candidate, without
    /// associating it with a specific license. `isHashed` indicates whether
    /// `passphrase` is already a SHA-256 hash, otherwise it is hashed before
    /// storage.
    func addPassphrase(
        _ passphrase: String,
        isHashed: Bool,
        userID: User.ID?,
        provider: LicenseDocument.Provider?
    ) async throws(LCPAddPassphraseError) {
        let hash: LCPPassphraseHash
        if isHashed {
            guard sha256Predicate.evaluate(with: passphrase) else {
                throw .invalidHash
            }
            // Normalize to lowercase to match `sha256()` output, so a hashed
            // value and the hash of the matching cleartext de-duplicate.
            hash = passphrase.lowercased()
        } else {
            hash = passphrase.sha256()
        }

        do {
            // An already-stored passphrase is not re-added, to avoid
            // overwriting its existing provider/userID association.
            let existing = try await repository.passphrases()
            guard !existing.contains(hash) else { return }

            try await repository.addPassphrase(hash, userID: userID, provider: provider)
        } catch {
            throw .repository(error)
        }
    }

    /// Finds any valid passphrase for the given license in the passphrases repository.
    /// If none is found, requests a passphrase from the request delegate (ie. user prompt) until
    /// one is valid, or the request is cancelled.
    /// The returned passphrase is nil if the request was cancelled by the user.
    func request(
        for license: LicenseDocument,
        authentication: LCPAuthenticating?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async throws -> LCPPassphraseHash? {
        // Look for a stored passphrase matching this license.
        //
        // Reading from the repository is best-effort: a keychain lookup failure
        // must not prevent the user from manually entering their passphrase.
        var passphrase = await findPassphrase(for: license)

        // Fallback on the provided `LCPAuthenticating` implementation.
        if passphrase == nil, let authentication = authentication {
            passphrase = try await authenticate(
                for: license,
                reason: .passphraseNotFound,
                using: authentication,
                allowUserInteraction: allowUserInteraction,
                sender: sender
            )
        }

        if let passphrase = passphrase {
            // Saves the passphrase to open the publication right away next time.
            do {
                try await repository.addPassphrase(passphrase, for: license)
            } catch {
                log(.error, "Failed to save the LCP passphrase to the repository: \(error)")
            }
        }

        return passphrase
    }

    /// Looks for a stored passphrase matching the given license.
    ///
    /// This is best-effort: any repository (e.g. keychain) failure is logged
    /// and treated as "no passphrase found", so that the interactive
    /// authentication fallback can still run.
    private func findPassphrase(for license: LicenseDocument) async -> LCPPassphraseHash? {
        do {
            // Look for alternative candidates based on the provider and user ID.
            let candidates = try await repository.passphrasesMatching(
                userID: license.user.id,
                provider: license.provider
            )
            if let passphrase = findValidPassphrase(in: candidates, for: license) {
                return passphrase
            }

            // The legacy SQLite database did not save all the new (passphrase,
            // userID, provider) tuples. So we need to fall back on checking all
            // the saved passphrases for a match.
            return try await findValidPassphrase(in: repository.passphrases(), for: license)
        } catch {
            log(.error, "Failed to look up alternate LCP passphrases in the repository: \(error)")
            return nil
        }
    }

    private func findValidPassphrase(in hashes: [LCPPassphraseHash], for license: LicenseDocument) -> LCPPassphraseHash? {
        guard !hashes.isEmpty else {
            return nil
        }
        return client.findOneValidPassphrase(jsonLicense: license.jsonString, hashedPassphrases: hashes)
    }

    /// Called when the service can't find any valid passphrase in the repository, as a fallback.
    private func authenticate(
        for license: LicenseDocument,
        reason: LCPAuthenticationReason,
        using authentication: LCPAuthenticating,
        allowUserInteraction: Bool,
        sender: Any?
    ) async throws -> LCPPassphraseHash? {
        let authenticatedLicense = LCPAuthenticatedLicense(document: license)
        guard let clearPassphrase = await authentication.retrievePassphrase(
            for: authenticatedLicense,
            reason: reason,
            allowUserInteraction: allowUserInteraction,
            sender: sender
        ) else {
            return nil
        }

        let hashedPassphrase = clearPassphrase.sha256()
        var passphrases = [hashedPassphrase]
        // Note: The C++ LCP lib crashes if we provide a passphrase that is not a valid
        // SHA-256 hash. So we check this beforehand.
        if sha256Predicate.evaluate(with: clearPassphrase) {
            passphrases.append(clearPassphrase)
        }

        guard let passphrase = client.findOneValidPassphrase(
            jsonLicense: license.jsonString,
            hashedPassphrases: passphrases
        ) else {
            // Delays a bit to make sure any dialog was dismissed.
            try await Task.sleep(seconds: 0.3)

            // Tries again if the passphrase is invalid, until cancelled
            return try await authenticate(
                for: license,
                reason: .invalidPassphrase,
                using: authentication,
                allowUserInteraction: allowUserInteraction,
                sender: sender
            )
        }

        return passphrase
    }
}
