//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

/// Errors occurring in ``LCPKeychainPassphraseRepository``.
public enum LCPKeychainPassphraseRepositoryError: Error {
    /// An error occurred while accessing the keychain.
    case keychain(KeychainError)

    /// An error occurred while decoding or encoding a passphrase.
    case coding(Error)
}

/// Keychain-based implementation of ``LCPPassphraseRepository``.
///
/// Stores passphrase hashes securely in the iOS/macOS Keychain with optional
/// iCloud synchronization.
public actor LCPKeychainPassphraseRepository: LCPPassphraseRepository, Loggable {
    /// Internal data structure for storing passphrase information in the
    /// Keychain.
    private struct Passphrase: Codable {
        /// Unique identifier for the license this passphrase belongs to.
        let licenseID: LicenseDocument.ID

        /// The hashed passphrase.
        var passphraseHash: LCPPassphraseHash

        /// The license provider.
        var provider: LicenseDocument.Provider

        /// The user identifier.
        var userID: User.ID?

        /// Date this passphrase was added to the Keychain.
        let created: Date

        /// Date this passphrase was updated in the Keychain.
        var updated: Date
    }

    private let keychain: Keychain
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Initializes a Keychain-based passphrase repository.
    ///
    /// - Parameters:
    ///   - synchronizable: Whether items should sync via iCloud Keychain.
    public init(synchronizable: Bool = true) {
        keychain = Keychain(
            serviceName: "org.readium.lcp.passphrases",
            synchronizable: synchronizable
        )

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - LCPPassphraseRepository

    public func passphrase(for licenseID: LicenseDocument.ID) async throws -> LCPPassphraseHash? {
        try getPassphrase(for: licenseID)?.passphraseHash
    }

    public func passphrasesMatching(
        userID: User.ID?,
        provider: LicenseDocument.Provider
    ) async throws -> [LCPPassphraseHash] {
        try await getAllPassphrases()
            .filter { passphrase in
                passphrase.provider == provider && (userID == nil || passphrase.userID == userID)
            }
            .map(\.passphraseHash)
    }

    public func passphrases() async throws -> [LCPPassphraseHash] {
        try await getAllPassphrases()
            .map(\.passphraseHash)
    }

    public func addPassphrase(
        _ hash: LCPPassphraseHash,
        for licenseID: LicenseDocument.ID,
        userID: User.ID?,
        provider: LicenseDocument.Provider
    ) async throws {
        if var passphrase = try getPassphrase(for: licenseID) {
            passphrase.passphraseHash = hash
            passphrase.provider = provider
            passphrase.userID = userID
            try updatePassphrase(passphrase, for: licenseID)
        } else {
            let passphrase = Passphrase(
                licenseID: licenseID,
                passphraseHash: hash,
                provider: provider,
                userID: userID,
                created: Date(),
                updated: Date()
            )

            try addPassphrase(passphrase, for: licenseID)
        }
    }

    /// Removes all passphrases from the repository.
    public func clear() async throws {
        do {
            try keychain.deleteAll()
        } catch {
            throw LCPKeychainPassphraseRepositoryError.keychain(error)
        }
    }

    // MARK: - Keychain Access

    private func getAllPassphrases() async throws(LCPKeychainPassphraseRepositoryError) -> [Passphrase] {
        try getAllFromKeychain()
            .compactMap { _, data in
                guard let passphrase = try? decoder.decode(Passphrase.self, from: data) else {
                    return nil
                }
                return passphrase
            }
    }

    /// Gets a passphrase from the Keychain for the given license ID.
    private func getPassphrase(for licenseID: LicenseDocument.ID) throws(LCPKeychainPassphraseRepositoryError) -> Passphrase? {
        guard let data = try getFromKeychain(id: licenseID) else {
            return nil
        }

        return try decode(data)
    }

    /// Adds a new passphrase to the Keychain.
    private func addPassphrase(_ passphrase: Passphrase, for id: LicenseDocument.ID) throws(LCPKeychainPassphraseRepositoryError) {
        try addToKeychain(data: encode(passphrase), for: id)
    }

    /// Updates an existing passphrase in the Keychain.
    private func updatePassphrase(_ passphrase: Passphrase, for id: LicenseDocument.ID) throws(LCPKeychainPassphraseRepositoryError) {
        var passphrase = passphrase
        passphrase.updated = Date()
        let data = try encode(passphrase)
        try updateKeychain(data: data, for: id)
    }

    // MARK: - Low-Level Helpers

    private func getFromKeychain(id: LicenseDocument.ID) throws(LCPKeychainPassphraseRepositoryError) -> Data? {
        do {
            return try keychain.load(forKey: id)
        } catch {
            throw .keychain(error)
        }
    }

    private func getAllFromKeychain() throws(LCPKeychainPassphraseRepositoryError) -> [String: Data] {
        do {
            return try keychain.allItems()
        } catch {
            throw .keychain(error)
        }
    }

    private func addToKeychain(data: Data, for id: LicenseDocument.ID) throws(LCPKeychainPassphraseRepositoryError) {
        do {
            try keychain.save(data: data, forKey: id)
        } catch {
            throw .keychain(error)
        }
    }

    private func updateKeychain(data: Data, for id: LicenseDocument.ID) throws(LCPKeychainPassphraseRepositoryError) {
        do {
            try keychain.update(data: data, forKey: id)
        } catch {
            throw .keychain(error)
        }
    }

    private func decode(_ data: Data) throws(LCPKeychainPassphraseRepositoryError) -> Passphrase {
        do {
            return try decoder.decode(Passphrase.self, from: data)
        } catch {
            throw .coding(error)
        }
    }

    private func encode(_ passphrase: Passphrase) throws(LCPKeychainPassphraseRepositoryError) -> Data {
        do {
            return try encoder.encode(passphrase)
        } catch {
            throw .coding(error)
        }
    }
}
