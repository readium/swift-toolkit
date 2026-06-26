//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CryptoSwift
import Foundation
import ReadiumInternal
import ReadiumShared

final class PassphrasesService: Loggable, Sendable {
    private let client: LCPClient
    private let repository: LCPPassphraseRepository

    init(client: LCPClient, repository: LCPPassphraseRepository) {
        self.client = client
        self.repository = repository
    }

    /// Finds any valid passphrase for the given license in the passphrases repository.
    /// If none is found, requests a passphrase from the request delegate (ie. user prompt) until
    /// one is valid, or the request is cancelled.
    /// The returned passphrase is nil if the request was cancelled by the user.
    func request(
        for license: LicenseDocument,
        authentication: LCPAuthenticating?,
        allowUserInteraction: Bool,
        sender: UncheckedSendable<Any?>?
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
        sender: UncheckedSendable<Any?>?
    ) async throws -> LCPPassphraseHash? {
        let authenticatedLicense = LCPAuthenticatedLicense(document: license)
        guard let clearPassphrase = await retrievePassphrase(
            using: authentication,
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
        if clearPassphrase.count == 64, clearPassphrase.allSatisfy({ $0.isASCII && $0.isHexDigit }) {
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

    /// Prompts the user for a passphrase on the main actor.
    ///
    /// The non-`Sendable` `sender` is unwrapped here, inside the main actor, so
    /// it never crosses an actor boundary.
    @MainActor
    private func retrievePassphrase(
        using authentication: LCPAuthenticating,
        for license: LCPAuthenticatedLicense,
        reason: LCPAuthenticationReason,
        allowUserInteraction: Bool,
        sender: UncheckedSendable<Any?>?
    ) async -> String? {
        await authentication.retrievePassphrase(
            for: license,
            reason: reason,
            allowUserInteraction: allowUserInteraction,
            sender: sender?.value
        )
    }
}
