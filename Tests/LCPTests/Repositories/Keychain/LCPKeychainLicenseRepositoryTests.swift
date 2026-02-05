//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP
import ReadiumShared
import Testing

@Suite struct LCPKeychainLicenseRepositoryTests {
    let repository: LCPKeychainLicenseRepository

    init() throws {
        repository = LCPKeychainLicenseRepository(
            synchronizable: false
        )
        // Clean up any existing test data
        try? cleanupAllTestData()
    }

    private func cleanupAllTestData() throws {
        // Delete all test licenses by using the Keychain directly
        let keychain = Keychain(
            serviceName: "org.readium.lcp.licenses",
            synchronizable: false
        )
        try keychain.deleteAll()
    }

    // MARK: - Test Helpers

    private func createTestLicenseDocument(
        id: String = UUID().uuidString,
        printLimit: Int? = 10,
        copyLimit: Int? = 100
    ) throws -> LicenseDocument {
        let licenseJSON = """
        {
            "provider": "https://test.provider.com",
            "id": "\(id)",
            "issued": "2024-01-01T00:00:00Z",
            "updated": "2024-01-01T00:00:00Z",
            "encryption": {
                "profile": "http://readium.org/lcp/basic-profile",
                "content_key": {
                    "algorithm": "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
                    "encrypted_value": "dGVzdA=="
                },
                "user_key": {
                    "algorithm": "http://www.w3.org/2001/04/xmlenc#sha256",
                    "text_hint": "Enter your passphrase",
                    "key_check": "dGVzdA=="
                }
            },
            "links": [
                {
                    "rel": "publication",
                    "href": "https://test.com/publication",
                    "type": "application/epub+zip"
                }
            ],
            "user": {
                "id": "user123",
                "email": "test@example.com",
                "name": "Test User"
            },
            "rights": {
                \(printLimit != nil ? "\"print\": \(printLimit!)," : "")
                \(copyLimit != nil ? "\"copy\": \(copyLimit!)," : "")
                "start": "2024-01-01T00:00:00Z"
            },
            "signature": {
                "algorithm": "http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256",
                "certificate": "dGVzdA==",
                "value": "dGVzdA=="
            }
        }
        """

        let data = licenseJSON.data(using: .utf8)!
        return try LicenseDocument(data: data)
    }

    // MARK: - AddLicense Tests

    @Test func addLicenseNewLicense() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(
            id: "test-license-1",
            printLimit: 5,
            copyLimit: 50
        )

        try await repository.addLicense(license)

        // Verify the license was added
        let storedLicense = try await repository.license(for: license.id)
        #expect(storedLicense != nil)
        #expect(storedLicense?.id == license.id)

        // Verify user rights were initialized
        let rights = try await repository.userRights(for: license.id)
        #expect(rights.print == 5)
        #expect(rights.copy == 50)

        // Verify device not registered initially
        let registered = try await repository.isDeviceRegistered(for: license.id)
        #expect(!registered)
    }

    @Test func addLicenseExistingLicenseDoesNotOverwriteRights() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(
            id: "test-license-2",
            printLimit: 10,
            copyLimit: 100
        )

        // Add license first time
        try await repository.addLicense(license)

        // Consume some rights
        try await repository.updateUserRights(for: license.id) { rights in
            rights.print = 5
            rights.copy = 50
        }

        // Add license again (simulating re-adding same license)
        try await repository.addLicense(license)

        // Rights should NOT be reset
        let rights = try await repository.userRights(for: license.id)
        #expect(rights.print == 5)
        #expect(rights.copy == 50)
    }

    @Test func addLicenseWithNilRights() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(
            id: "test-license-unlimited",
            printLimit: nil,
            copyLimit: nil
        )

        try await repository.addLicense(license)

        let rights = try await repository.userRights(for: license.id)
        #expect(rights.print == nil)
        #expect(rights.copy == nil)
    }

    // MARK: - License Retrieval Tests

    @Test func licenseRetrievalReturnsStoredDocument() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(id: "test-license-retrieve")

        try await repository.addLicense(license)

        let retrieved = try await repository.license(for: license.id)
        #expect(retrieved != nil)
        #expect(retrieved?.id == license.id)
        #expect(retrieved?.provider == license.provider)
        #expect(retrieved?.user.id == license.user.id)
    }

    @Test func licenseRetrievalNonExistentReturnsNil() async throws {
        defer { try? cleanupAllTestData() }

        let retrieved = try await repository.license(for: "non-existent-license")
        #expect(retrieved == nil)
    }

    // MARK: - Device Registration Tests

    @Test func deviceRegistrationInitiallyFalse() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(id: "test-registration-1")
        try await repository.addLicense(license)

        let registered = try await repository.isDeviceRegistered(for: license.id)
        #expect(!registered)
    }

    @Test func registerDevice() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(id: "test-registration-2")
        try await repository.addLicense(license)

        try await repository.registerDevice(for: license.id)

        let registered = try await repository.isDeviceRegistered(for: license.id)
        #expect(registered)
    }

    @Test func registerDeviceIdempotent() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(id: "test-registration-3")
        try await repository.addLicense(license)

        try await repository.registerDevice(for: license.id)
        try await repository.registerDevice(for: license.id)

        let registered = try await repository.isDeviceRegistered(for: license.id)
        #expect(registered)
    }

    @Test func deviceRegistrationNonExistentLicenseThrows() async throws {
        defer { try? cleanupAllTestData() }

        await #expect(throws: (any Error).self) {
            _ = try await repository.isDeviceRegistered(for: "non-existent")
        }
    }

    @Test func registerDeviceNonExistentLicenseThrows() async throws {
        defer { try? cleanupAllTestData() }

        await #expect(throws: (any Error).self) {
            try await repository.registerDevice(for: "non-existent")
        }
    }

    // MARK: - User Rights Tests

    @Test func userRightsRetrieval() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(
            id: "test-rights-1",
            printLimit: 20,
            copyLimit: 200
        )
        try await repository.addLicense(license)

        let rights = try await repository.userRights(for: license.id)
        #expect(rights.print == 20)
        #expect(rights.copy == 200)
    }

    @Test func userRightsNonExistentLicenseThrows() async throws {
        defer { try? cleanupAllTestData() }

        await #expect(throws: (any Error).self) {
            _ = try await repository.userRights(for: "non-existent")
        }
    }

    @Test func updateUserRights() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(
            id: "test-rights-update",
            printLimit: 10,
            copyLimit: 100
        )
        try await repository.addLicense(license)

        try await repository.updateUserRights(for: license.id) { rights in
            rights.print = 5
            rights.copy = 50
        }

        let updatedRights = try await repository.userRights(for: license.id)
        #expect(updatedRights.print == 5)
        #expect(updatedRights.copy == 50)
    }

    @Test func updateUserRightsDecrement() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(
            id: "test-rights-decrement",
            printLimit: 10,
            copyLimit: 100
        )
        try await repository.addLicense(license)

        // Simulate consuming a print
        try await repository.updateUserRights(for: license.id) { rights in
            if let currentPrint = rights.print {
                rights.print = max(0, currentPrint - 1)
            }
        }

        let rights = try await repository.userRights(for: license.id)
        #expect(rights.print == 9)
        #expect(rights.copy == 100)
    }

    @Test func updateUserRightsToNil() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(
            id: "test-rights-nil",
            printLimit: 10,
            copyLimit: 100
        )
        try await repository.addLicense(license)

        try await repository.updateUserRights(for: license.id) { rights in
            rights.print = nil
            rights.copy = nil
        }

        let rights = try await repository.userRights(for: license.id)
        #expect(rights.print == nil)
        #expect(rights.copy == nil)
    }

    @Test func updateUserRightsNonExistentLicenseThrows() async throws {
        defer { try? cleanupAllTestData() }

        await #expect(throws: (any Error).self) {
            try await repository.updateUserRights(for: "non-existent") { _ in }
        }
    }

    // MARK: - Concurrency Tests

    @Test func concurrentAddLicense() async throws {
        defer { try? cleanupAllTestData() }

        let licenses = try (0 ..< 5).map { index in
            try createTestLicenseDocument(id: "concurrent-\(index)")
        }

        // Add licenses concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for license in licenses {
                group.addTask {
                    try await repository.addLicense(license)
                }
            }
            try await group.waitForAll()
        }

        // Verify all licenses were added
        for license in licenses {
            let stored = try await repository.license(for: license.id)
            #expect(stored != nil)
        }
    }

    @Test func concurrentUserRightsUpdate() async throws {
        defer { try? cleanupAllTestData() }

        let license = try createTestLicenseDocument(
            id: "concurrent-rights",
            printLimit: 100,
            copyLimit: 1000
        )
        try await repository.addLicense(license)

        // Perform concurrent updates
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    try await repository.updateUserRights(for: license.id) { rights in
                        if let currentPrint = rights.print {
                            rights.print = max(0, currentPrint - 1)
                        }
                    }
                }
            }
            try await group.waitForAll()
        }

        // Verify rights were decremented correctly
        // Note: Due to actor serialization, all updates should apply
        let rights = try await repository.userRights(for: license.id)
        #expect(rights.print == 90)
    }

    // MARK: - Multiple License Tests

    @Test func multipleLicenses() async throws {
        defer { try? cleanupAllTestData() }

        let license1 = try createTestLicenseDocument(
            id: "multi-1",
            printLimit: 5,
            copyLimit: 50
        )
        let license2 = try createTestLicenseDocument(
            id: "multi-2",
            printLimit: 10,
            copyLimit: 100
        )
        let license3 = try createTestLicenseDocument(
            id: "multi-3",
            printLimit: 15,
            copyLimit: 150
        )

        try await repository.addLicense(license1)
        try await repository.addLicense(license2)
        try await repository.addLicense(license3)

        let rights1 = try await repository.userRights(for: "multi-1")
        let rights2 = try await repository.userRights(for: "multi-2")
        let rights3 = try await repository.userRights(for: "multi-3")

        #expect(rights1.print == 5)
        #expect(rights2.print == 10)
        #expect(rights3.print == 15)
    }
}
