//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP
import ReadiumShared
import Testing

enum UserTests {
    struct Decrypted {
        @Test func decryptsEncryptedFields() throws {
            let user = User(
                id: "1234",
                email: base64("secret:john@example.com"),
                name: base64("secret:John"),
                encrypted: ["email", "name"]
            )

            let decrypted = try user.decrypted(revealSecret)

            #expect(decrypted.id == "1234")
            #expect(decrypted.email == "john@example.com")
            #expect(decrypted.name == "John")
            #expect(decrypted.encrypted.isEmpty)
        }

        @Test func leavesClearFieldsUntouched() throws {
            let user = User(
                id: "1234",
                email: "john@example.com",
                name: base64("secret:John"),
                encrypted: ["name"]
            )

            let decrypted = try user.decrypted(revealSecret)

            #expect(decrypted.email == "john@example.com")
            #expect(decrypted.name == "John")
            #expect(decrypted.encrypted.isEmpty)
        }

        @Test func decryptsIDAndExtensions() throws {
            let user = User(
                id: base64("secret:1234"),
                extensions: [
                    "http://example.com/subscription": JSONValue.string(base64("secret:premium")),
                    "http://example.com/age": JSONValue.integer(42),
                ],
                encrypted: ["id", "http://example.com/subscription"]
            )

            let decrypted = try user.decrypted(revealSecret)

            #expect(decrypted.id == "1234")
            #expect(decrypted.extensions == [
                "http://example.com/subscription": JSONValue.string("premium"),
                "http://example.com/age": JSONValue.integer(42),
            ])
            #expect(decrypted.encrypted.isEmpty)
        }

        @Test func keepsFieldsThatCannotBeDeciphered() throws {
            let user = User(
                email: base64("secret:john@example.com"),
                name: base64("secret:John"),
                encrypted: ["email", "name"]
            )

            // Refuses to decrypt the email.
            let decrypted = try user.decrypted { data in
                let string = String(data: data, encoding: .utf8)!
                return string.contains("john") ? nil : revealSecret(data)
            }

            #expect(decrypted.email == base64("secret:john@example.com"))
            #expect(decrypted.name == "John")
            #expect(decrypted.encrypted == ["email"])
        }

        @Test func keepsFieldsWhenDecryptionAlwaysFails() throws {
            let user = User(
                email: base64("secret:john@example.com"),
                name: base64("secret:John"),
                encrypted: ["email", "name"]
            )

            // Emulates a liblcp build unable to decipher the fields.
            let decrypted = try user.decrypted { _ in nil }

            #expect(decrypted.email == user.email)
            #expect(decrypted.name == user.name)
            #expect(decrypted.encrypted == ["email", "name"])
        }

        @Test func keepsFieldsThatAreNotValidBase64() throws {
            let user = User(
                name: "n o t b a s e 6 4",
                encrypted: ["name"]
            )

            let decrypted = try user.decrypted(revealSecret)

            #expect(decrypted.name == "n o t b a s e 6 4")
            #expect(decrypted.encrypted == ["name"])
        }

        @Test func ignoresDuplicateEncryptedFields() throws {
            let user = User(
                name: base64("secret:John"),
                encrypted: ["name", "name"]
            )

            let decrypted = try user.decrypted(revealSecret)

            // The second occurrence must not decrypt the plain text again.
            #expect(decrypted.name == "John")
            #expect(decrypted.encrypted.isEmpty)
        }

        @Test func keepsUnknownEncryptedFields() throws {
            let user = User(
                name: base64("secret:John"),
                encrypted: ["name", "unknown-field"]
            )

            let decrypted = try user.decrypted(revealSecret)

            #expect(decrypted.name == "John")
            #expect(decrypted.encrypted == ["unknown-field"])
        }

        @Test func rethrowsDecryptionErrors() {
            let user = User(
                name: base64("secret:John"),
                encrypted: ["name"]
            )

            #expect(throws: DummyError.self) {
                try user.decrypted { _ in throw DummyError() }
            }
        }
    }
}

// MARK: - Helpers

/// Fake decryption: the "encrypted" value is the plain text prefixed with
/// `secret:`, then Base64-encoded.
private func revealSecret(_ data: Data) -> Data? {
    let string = String(data: data, encoding: .utf8)!
    guard string.hasPrefix("secret:") else {
        return nil
    }
    return Data(string.dropFirst("secret:".count).utf8)
}

private func base64(_ string: String) -> String {
    Data(string.utf8).base64EncodedString()
}

private struct DummyError: Error {}
