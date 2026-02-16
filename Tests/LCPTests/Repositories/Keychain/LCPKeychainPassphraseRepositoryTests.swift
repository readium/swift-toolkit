//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP
import ReadiumShared
import Testing

@Suite struct LCPKeychainPassphraseRepositoryTests {
    let repository: LCPKeychainPassphraseRepository

    init() throws {
        repository = LCPKeychainPassphraseRepository(
            synchronizable: false
        )
        // Clean up any existing test data
        try? cleanupAllTestData()
    }

    private func cleanupAllTestData() throws {
        // Delete all test passphrases by using the Keychain directly
        let keychain = Keychain(
            serviceName: "org.readium.lcp.passphrases",
            synchronizable: false
        )
        try keychain.deleteAll()
    }

    // MARK: - AddPassphrase Tests

    @Test func addPassphrase() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase(
            "hash123",
            for: "license-1",
            userID: "user-1",
            provider: "https://provider.com"
        )

        let retrieved = try await repository.passphrase(for: "license-1")
        #expect(retrieved == "hash123")
    }

    @Test func addPassphraseUpsert() async throws {
        defer { try? cleanupAllTestData() }

        // Add initial passphrase
        try await repository.addPassphrase(
            "hash-old",
            for: "license-2",
            userID: "user-1",
            provider: "https://provider.com"
        )

        // Update with new passphrase
        try await repository.addPassphrase(
            "hash-new",
            for: "license-2",
            userID: "user-1",
            provider: "https://provider.com"
        )

        let retrieved = try await repository.passphrase(for: "license-2")
        #expect(retrieved == "hash-new")
    }

    @Test func addPassphraseWithNilUserID() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase(
            "hash-no-user",
            for: "license-3",
            userID: nil,
            provider: "https://provider.com"
        )

        let retrieved = try await repository.passphrase(for: "license-3")
        #expect(retrieved == "hash-no-user")
    }

    // MARK: - Passphrase Retrieval Tests

    @Test func passphraseForLicense() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase(
            "hash-retrieve",
            for: "license-retrieve",
            userID: "user-1",
            provider: "https://provider.com"
        )

        let passphrase = try await repository.passphrase(for: "license-retrieve")
        #expect(passphrase == "hash-retrieve")
    }

    @Test func passphraseForNonExistentLicense() async throws {
        defer { try? cleanupAllTestData() }

        let passphrase = try await repository.passphrase(for: "non-existent-license")
        #expect(passphrase == nil)
    }

    // MARK: - PassphrasesMatching Tests

    @Test func passphrasesMatchingByProviderAndUserID() async throws {
        defer { try? cleanupAllTestData() }

        // Add passphrases with different providers and user IDs
        try await repository.addPassphrase(
            "hash-1",
            for: "license-1",
            userID: "user-1",
            provider: "https://provider1.com"
        )
        try await repository.addPassphrase(
            "hash-2",
            for: "license-2",
            userID: "user-1",
            provider: "https://provider1.com"
        )
        try await repository.addPassphrase(
            "hash-3",
            for: "license-3",
            userID: "user-2",
            provider: "https://provider1.com"
        )
        try await repository.addPassphrase(
            "hash-4",
            for: "license-4",
            userID: "user-1",
            provider: "https://provider2.com"
        )

        // Search for passphrases with provider1 and user-1
        let matches = try await repository.passphrasesMatching(
            userID: "user-1",
            provider: "https://provider1.com"
        )

        #expect(Set(matches) == Set(["hash-1", "hash-2"]))
    }

    @Test func passphrasesMatchingByProviderOnly() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase(
            "hash-1",
            for: "license-1",
            userID: "user-1",
            provider: "https://provider.com"
        )
        try await repository.addPassphrase(
            "hash-2",
            for: "license-2",
            userID: "user-2",
            provider: "https://provider.com"
        )
        try await repository.addPassphrase(
            "hash-3",
            for: "license-3",
            userID: "user-3",
            provider: "https://other-provider.com"
        )

        // Search with nil userID should match all for the provider
        let matches = try await repository.passphrasesMatching(
            userID: nil,
            provider: "https://provider.com"
        )

        #expect(Set(matches) == Set(["hash-1", "hash-2"]))
    }

    @Test func passphrasesMatchingNoMatches() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase(
            "hash-1",
            for: "license-1",
            userID: "user-1",
            provider: "https://provider.com"
        )

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

    @Test func multiplePassphrasesForDifferentLicenses() async throws {
        defer { try? cleanupAllTestData() }

        let passphrases = [
            ("license-1", "hash-1"),
            ("license-2", "hash-2"),
            ("license-3", "hash-3"),
        ]

        for (licenseID, hash) in passphrases {
            try await repository.addPassphrase(
                hash,
                for: licenseID,
                userID: "user-1",
                provider: "https://provider.com"
            )
        }

        // Verify each passphrase can be retrieved
        for (licenseID, expectedHash) in passphrases {
            let retrieved = try await repository.passphrase(for: licenseID)
            #expect(retrieved == expectedHash)
        }
    }

    // MARK: - Concurrency Tests

    @Test func concurrentAddPassphrase() async throws {
        defer { try? cleanupAllTestData() }

        let passphrases = (0 ..< 10).map { index in
            ("license-concurrent-\(index)", "hash-\(index)")
        }

        // Add passphrases concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (licenseID, hash) in passphrases {
                group.addTask {
                    try await repository.addPassphrase(
                        hash,
                        for: licenseID,
                        userID: "user-1",
                        provider: "https://provider.com"
                    )
                }
            }
            try await group.waitForAll()
        }

        // Verify all passphrases were added
        for (licenseID, expectedHash) in passphrases {
            let retrieved = try await repository.passphrase(for: licenseID)
            #expect(retrieved == expectedHash)
        }
    }

    // MARK: - Clear Tests

    @Test func clearRemovesAllPassphrases() async throws {
        defer { try? cleanupAllTestData() }

        try await repository.addPassphrase(
            "hash-1",
            for: "license-clear-1",
            userID: "user-1",
            provider: "https://provider.com"
        )
        try await repository.addPassphrase(
            "hash-2",
            for: "license-clear-2",
            userID: "user-2",
            provider: "https://provider.com"
        )

        try await repository.clear()

        // Verify all passphrases are gone
        #expect(try await repository.passphrase(for: "license-clear-1") == nil)
        #expect(try await repository.passphrase(for: "license-clear-2") == nil)
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

        for (index, hash) in specialHashes.enumerated() {
            try await repository.addPassphrase(
                hash,
                for: "license-special-\(index)",
                userID: "user-1",
                provider: "https://provider.com"
            )

            let retrieved = try await repository.passphrase(for: "license-special-\(index)")
            #expect(retrieved == hash)
        }
    }

    @Test func providerWithSpecialCharacters() async throws {
        defer { try? cleanupAllTestData() }

        let providers = [
            "https://provider.com/path?query=value",
            "https://provider.com:8080",
            "https://provider.com/path#fragment",
        ]

        for (index, provider) in providers.enumerated() {
            try await repository.addPassphrase(
                "hash-\(index)",
                for: "license-provider-\(index)",
                userID: "user-1",
                provider: provider
            )

            let matches = try await repository.passphrasesMatching(
                userID: "user-1",
                provider: provider
            )

            #expect(matches.contains("hash-\(index)"))
        }
    }

    // MARK: - Edge Cases Tests

    @Test func longPassphraseHash() async throws {
        defer { try? cleanupAllTestData() }

        // Test with very long hash (e.g., 512-bit hash)
        let longHash = String(repeating: "a", count: 128)

        try await repository.addPassphrase(
            longHash,
            for: "license-long-hash",
            userID: "user-1",
            provider: "https://provider.com"
        )

        let retrieved = try await repository.passphrase(for: "license-long-hash")
        #expect(retrieved == longHash)
    }

    @Test func longUserID() async throws {
        defer { try? cleanupAllTestData() }

        let longUserID = String(repeating: "u", count: 200)

        try await repository.addPassphrase(
            "hash",
            for: "license-long-user",
            userID: longUserID,
            provider: "https://provider.com"
        )

        let matches = try await repository.passphrasesMatching(
            userID: longUserID,
            provider: "https://provider.com"
        )

        #expect(matches == ["hash"])
    }

    @Test func longProvider() async throws {
        defer { try? cleanupAllTestData() }

        let longProvider = "https://provider.com/" + String(repeating: "p", count: 200)

        try await repository.addPassphrase(
            "hash",
            for: "license-long-provider",
            userID: "user-1",
            provider: longProvider
        )

        let matches = try await repository.passphrasesMatching(
            userID: "user-1",
            provider: longProvider
        )

        #expect(matches == ["hash"])
    }
}
