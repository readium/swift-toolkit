//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP
import ReadiumShared
import Testing

struct LCPKeychainPassphraseRepositoryTests {
    let repository: LCPKeychainPassphraseRepository

    private static let serviceName = "org.readium.lcp.passphrases"

    init() throws {
        repository = LCPKeychainPassphraseRepository(
            synchronizable: false
        )
        // Clean up any existing test data
        try? cleanupAllTestData()
    }

    private func cleanupAllTestData() throws {
        // Delete all test passphrases by using the Keychain directly
        try keychain().deleteAll()
    }

    private func keychain() -> Keychain {
        Keychain(serviceName: Self.serviceName, synchronizable: false)
    }

    /// Writes a legacy-format passphrase blob keyed by `licenseID`, mimicking
    /// data stored by a previous version of the repository.
    private func writeLegacyPassphrase(
        licenseID: String,
        hash: LCPPassphraseHash,
        userID: String?,
        provider: String
    ) throws {
        let date = ISO8601DateFormatter().string(from: Date())
        var blob: [String: Any] = [
            "licenseID": licenseID,
            "passphraseHash": hash,
            "provider": provider,
            "created": date,
            "updated": date,
        ]
        if let userID {
            blob["userID"] = userID
        }
        let data = try JSONSerialization.data(withJSONObject: blob)
        try keychain().save(data: data, forKey: licenseID)
    }

    // MARK: - AddPassphrase Tests

    @Test func addPassphrase() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase(
            "hash123",
            userID: "user-1",
            provider: "https://provider.com"
        )

        let all = try await repository.passphrases()
        #expect(all == ["hash123"])
    }

    @Test func addPassphraseUpdatesMetadataInPlace() async throws {
        defer { try? cleanupAllTestData() }

        // Add the same hash twice, with different metadata.
        try await repository.addPassphrase(
            "hash",
            userID: "user-1",
            provider: "https://provider1.com"
        )
        try await repository.addPassphrase(
            "hash",
            userID: "user-2",
            provider: "https://provider2.com"
        )

        // A single entry is kept, with the updated metadata.
        let all = try await repository.passphrases()
        #expect(all == ["hash"])

        let oldMatches = try await repository.passphrasesMatching(
            userID: "user-1",
            provider: "https://provider1.com"
        )
        #expect(oldMatches.isEmpty)

        let newMatches = try await repository.passphrasesMatching(
            userID: "user-2",
            provider: "https://provider2.com"
        )
        #expect(newMatches == ["hash"])
    }

    @Test func addPassphraseWithNilUserID() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase(
            "hash-no-user",
            userID: nil,
            provider: "https://provider.com"
        )

        let matches = try await repository.passphrasesMatching(
            userID: nil,
            provider: "https://provider.com"
        )
        #expect(matches == ["hash-no-user"])
    }

    @Test func addPassphraseWithNilProviderAndUser() async throws {
        defer { try? cleanupAllTestData() }

        // A passphrase can be stored without any license or provider.
        try await repository.addPassphrase("loose-hash")

        // It is returned by `passphrases()`...
        let all = try await repository.passphrases()
        #expect(all == ["loose-hash"])

        // ...but not matched by a specific-provider query.
        let matches = try await repository.passphrasesMatching(
            userID: nil,
            provider: "https://provider.com"
        )
        #expect(matches.isEmpty)
    }

    // MARK: - PassphrasesMatching Tests

    @Test func passphrasesMatchingByProviderAndUserID() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase("hash-1", userID: "user-1", provider: "https://provider1.com")
        try await repository.addPassphrase("hash-2", userID: "user-1", provider: "https://provider1.com")
        try await repository.addPassphrase("hash-3", userID: "user-2", provider: "https://provider1.com")
        try await repository.addPassphrase("hash-4", userID: "user-1", provider: "https://provider2.com")

        let matches = try await repository.passphrasesMatching(
            userID: "user-1",
            provider: "https://provider1.com"
        )

        #expect(Set(matches) == Set(["hash-1", "hash-2"]))
    }

    @Test func passphrasesMatchingByProviderOnly() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase("hash-1", userID: "user-1", provider: "https://provider.com")
        try await repository.addPassphrase("hash-2", userID: "user-2", provider: "https://provider.com")
        try await repository.addPassphrase("hash-3", userID: "user-3", provider: "https://other-provider.com")

        // Search with nil userID should match all for the provider
        let matches = try await repository.passphrasesMatching(
            userID: nil,
            provider: "https://provider.com"
        )

        #expect(Set(matches) == Set(["hash-1", "hash-2"]))
    }

    @Test func passphrasesMatchingNoMatches() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase("hash-1", userID: "user-1", provider: "https://provider.com")

        let matches = try await repository.passphrasesMatching(
            userID: "user-99",
            provider: "https://non-existent.com"
        )

        #expect(matches.isEmpty)
    }

    @Test func passphrasesMatchingEmptyRepository() async throws {
        defer { try? cleanupAllTestData() }

        let matches = try await repository.passphrasesMatching(
            userID: "user-1",
            provider: "https://provider.com"
        )

        #expect(matches.isEmpty)
    }

    // MARK: - Multiple Passphrases Tests

    @Test func multiplePassphrases() async throws {
        defer { try? cleanupAllTestData() }

        let hashes = ["hash-1", "hash-2", "hash-3"]

        for hash in hashes {
            try await repository.addPassphrase(hash, userID: "user-1", provider: "https://provider.com")
        }

        let all = try await repository.passphrases()
        #expect(Set(all) == Set(hashes))
    }

    // MARK: - Backward Compatibility Tests

    @Test func readsLegacyLicenseKeyedPassphrase() async throws {
        defer { try? cleanupAllTestData() }

        // Stored by a previous version: keyed by licenseID, with a non-optional
        // provider and an extra `licenseID` field.
        try writeLegacyPassphrase(
            licenseID: "license-legacy",
            hash: "legacy-hash",
            userID: "user-1",
            provider: "https://provider.com"
        )

        let all = try await repository.passphrases()
        #expect(all == ["legacy-hash"])

        let matches = try await repository.passphrasesMatching(
            userID: "user-1",
            provider: "https://provider.com"
        )
        #expect(matches == ["legacy-hash"])
    }

    // MARK: - Concurrency Tests

    @Test func concurrentAddPassphrase() async throws {
        defer { try? cleanupAllTestData() }

        let hashes = (0 ..< 10).map { "hash-\($0)" }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for hash in hashes {
                group.addTask {
                    try await repository.addPassphrase(
                        hash,
                        userID: "user-1",
                        provider: "https://provider.com"
                    )
                }
            }
            try await group.waitForAll()
        }

        let all = try await repository.passphrases()
        #expect(Set(all) == Set(hashes))
    }

    // MARK: - Clear Tests

    @Test func clearRemovesAllPassphrases() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase("hash-1", userID: "user-1", provider: "https://provider.com")
        try await repository.addPassphrase("hash-2", userID: "user-2", provider: "https://provider.com")

        try await repository.clear()

        let all = try await repository.passphrases()
        #expect(all.isEmpty)
    }

    @Test func clearOnEmptyRepositorySucceeds() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.clear()
    }

    // MARK: - Special Characters Tests

    @Test func passphraseWithSpecialCharacters() async throws {
        defer { try? cleanupAllTestData() }

        let specialHashes = [
            "hash+with+plus",
            "hash/with/slash",
            "hash=with=equals",
            "hash-with-unicode-é-ñ-中",
        ]

        for hash in specialHashes {
            try await repository.addPassphrase(hash, userID: "user-1", provider: "https://provider.com")
        }

        let all = try await repository.passphrases()
        #expect(Set(all) == Set(specialHashes))
    }

    @Test func providerWithSpecialCharacters() async throws {
        defer { try? cleanupAllTestData() }

        let providers = [
            "https://provider.com/path?query=value",
            "https://provider.com:8080",
            "https://provider.com/path#fragment",
        ]

        for (index, provider) in providers.enumerated() {
            try await repository.addPassphrase("hash-\(index)", userID: "user-1", provider: provider)

            let matches = try await repository.passphrasesMatching(userID: "user-1", provider: provider)
            #expect(matches.contains("hash-\(index)"))
        }
    }

    // MARK: - Edge Cases Tests

    @Test func longPassphraseHash() async throws {
        defer { try? cleanupAllTestData() }

        // Test with very long hash (e.g., 512-bit hash)
        let longHash = String(repeating: "a", count: 128)

        try await repository.addPassphrase(longHash, userID: "user-1", provider: "https://provider.com")

        let all = try await repository.passphrases()
        #expect(all == [longHash])
    }

    @Test func longUserID() async throws {
        defer { try? cleanupAllTestData() }

        let longUserID = String(repeating: "u", count: 200)

        try await repository.addPassphrase("hash", userID: longUserID, provider: "https://provider.com")

        let matches = try await repository.passphrasesMatching(userID: longUserID, provider: "https://provider.com")
        #expect(matches == ["hash"])
    }

    @Test func longProvider() async throws {
        defer { try? cleanupAllTestData() }

        let longProvider = "https://provider.com/" + String(repeating: "p", count: 200)

        try await repository.addPassphrase("hash", userID: "user-1", provider: longProvider)

        let matches = try await repository.passphrasesMatching(userID: "user-1", provider: longProvider)
        #expect(matches == ["hash"])
    }
}
