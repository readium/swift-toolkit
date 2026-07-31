//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP
@testable import ReadiumShared
import Testing

final class MockLCPClient: LCPClient, @unchecked Sendable {
    var validPassphrase: LCPPassphraseHash?

    func createContext(jsonLicense: String, hashedPassphrase: ReadiumLCP.LCPPassphraseHash, pemCrl: String) throws -> ReadiumLCP.LCPClientContext {
        ""
    }

    func decrypt(data: Data, using context: ReadiumLCP.LCPClientContext) -> Data? {
        data
    }

    func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [ReadiumLCP.LCPPassphraseHash]) -> ReadiumLCP.LCPPassphraseHash? {
        if let valid = validPassphrase, hashedPassphrases.contains(valid) {
            return valid
        }
        return nil
    }

    func getSupportedLCPProfileURIs() -> [String] {
        []
    }
}

final class MockLCPAuthenticating: LCPAuthenticating, @unchecked Sendable {
    var passphraseToReturn: String?

    @MainActor
    func retrievePassphrase(
        for license: ReadiumLCP.LCPAuthenticatedLicense,
        reason: ReadiumLCP.LCPAuthenticationReason,
        allowUserInteraction: Bool
    ) async -> String? {
        passphraseToReturn
    }
}

struct PassphrasesServiceTests {
    let client: MockLCPClient
    let repository: InMemoryLCPPassphraseRepository
    let service: PassphrasesService

    init() {
        client = MockLCPClient()
        repository = InMemoryLCPPassphraseRepository()
        service = PassphrasesService(client: client, repository: repository)
    }

    private func createTestLicenseDocument(id: String = UUID().uuidString) throws -> LicenseDocument {
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

    @Test func addPassphraseHashesAndStores() async throws {
        try await service.addPassphrase("my_passphrase", isHashed: false, userID: "user123", provider: "https://test.provider.com")

        let stored = try await repository.passphrases()
        #expect(stored.count == 1)
        #expect(stored.contains("my_passphrase".sha256()))
    }

    @Test func addHashedPassphraseStoresDirectly() async throws {
        let hash = "a".padding(toLength: 64, withPad: "0", startingAt: 0) // 64 hex characters
        try await service.addPassphrase(hash, isHashed: true, userID: "user123", provider: "https://test.provider.com")

        let stored = try await repository.passphrases()
        #expect(stored.count == 1)
        #expect(stored.contains(hash.lowercased()))
    }

    @Test func requestReturnsValidPassphraseFromRepository() async throws {
        let license = try createTestLicenseDocument()
        let validHash = "my_passphrase".sha256()

        client.validPassphrase = validHash

        try await service.addPassphrase("my_passphrase", isHashed: false, userID: "user123", provider: "https://test.provider.com")

        let auth = MockLCPAuthenticating()

        let result = try await service.request(for: license, authentication: auth, allowUserInteraction: true)
        #expect(result == validHash)
    }

    @Test func requestFallsBackToAuthentication() async throws {
        let license = try createTestLicenseDocument()
        let clearPassphrase = "my_passphrase"
        let validHash = clearPassphrase.sha256()

        client.validPassphrase = validHash

        let auth = MockLCPAuthenticating()
        auth.passphraseToReturn = clearPassphrase

        let result = try await service.request(for: license, authentication: auth, allowUserInteraction: true)
        #expect(result == validHash)

        let stored = try await repository.passphrases()
        #expect(stored.contains(validHash))
    }
}
