//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Errors occurring in ``LCPKeychainPassphraseRepository``.
public enum LCPKeychainPassphraseRepositoryError: Error, Sendable {
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
    ///
    /// Items are keyed in the Keychain by their ``passphraseHash``.
    private struct Passphrase: Codable {
        /// The hashed passphrase. Used as the Keychain account key.
        var passphraseHash: LCPPassphraseHash

        /// The license provider, if known.
        var provider: LicenseDocument.Provider?

        /// The user identifier, if known.
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
        userID: User.ID?,
        provider: LicenseDocument.Provider?
    ) async throws {
        if var passphrase = try getPassphrase(forHash: hash) {
            passphrase.provider = provider
            passphrase.userID = userID
            try updatePassphrase(passphrase, for: hash)
        } else {
            let passphrase = Passphrase(
                passphraseHash: hash,
                provider: provider,
                userID: userID,
                created: Date(),
                updated: Date()
            )

            try addPassphrase(passphrase, for: hash)
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

    /// Gets a passphrase from the Keychain for the given passphrase hash.
    private func getPassphrase(forHash hash: LCPPassphraseHash) throws(LCPKeychainPassphraseRepositoryError) -> Passphrase? {
        guard let data = try getFromKeychain(hash: hash) else {
            return nil
        }

        return try decode(data)
    }

    /// Adds a new passphrase to the Keychain.
    private func addPassphrase(_ passphrase: Passphrase, for hash: LCPPassphraseHash) throws(LCPKeychainPassphraseRepositoryError) {
        try addToKeychain(data: encode(passphrase), for: hash)
    }

    /// Updates an existing passphrase in the Keychain.
    private func updatePassphrase(_ passphrase: Passphrase, for hash: LCPPassphraseHash) throws(LCPKeychainPassphraseRepositoryError) {
        var passphrase = passphrase
        passphrase.updated = Date()
        let data = try encode(passphrase)
        try updateKeychain(data: data, for: hash)
    }

    // MARK: - Low-Level Helpers

    private func getFromKeychain(hash: LCPPassphraseHash) throws(LCPKeychainPassphraseRepositoryError) -> Data? {
        do {
            return try keychain.load(forKey: hash)
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

    private func addToKeychain(data: Data, for hash: LCPPassphraseHash) throws(LCPKeychainPassphraseRepositoryError) {
        do {
            try keychain.save(data: data, forKey: hash)
        } catch {
            throw .keychain(error)
        }
    }

    private func updateKeychain(data: Data, for hash: LCPPassphraseHash) throws(LCPKeychainPassphraseRepositoryError) {
        do {
            try keychain.update(data: data, forKey: hash)
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
