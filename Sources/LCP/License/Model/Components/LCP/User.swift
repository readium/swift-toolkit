//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public struct User: JSONValueDecodable, Sendable {
    public typealias ID = String

    /// Unique identifier for the User at a specific Provider.
    public let id: ID?
    /// The User’s e-mail address.
    public let email: String?
    /// The User’s name.
    public let name: String?
    /// Implementor-specific extensions. Each extension is identified by an URI.
    public let extensions: [String: JSONValue]
    /// A list of which user object values are encrypted in this License Document.
    public let encrypted: [String]

    public init(
        id: ID? = nil,
        email: String? = nil,
        name: String? = nil,
        extensions: [String: JSONValue] = [:],
        encrypted: [String] = []
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.extensions = extensions
        self.encrypted = encrypted
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }

        var dict = json.object ?? [:]

        id = dict.pop("id")?.string
        email = dict.pop("email")?.string
        name = dict.pop("name")?.string
        encrypted = dict.pop("encrypted")?.decode() ?? []
        extensions = dict
    }
}

extension User {
    /// Returns a copy of this User after deciphering the fields listed in
    /// `encrypted` with the given closure.
    ///
    /// `decrypt` receives the raw encrypted value (after Base64 decoding) and
    /// returns the deciphered plain text data, or nil if the field cannot be
    /// deciphered.
    ///
    /// Fields that cannot be deciphered are left untouched and still listed
    /// in `encrypted`.
    func decrypted(_ decrypt: (Data) throws -> Data?) rethrows -> User {
        func decryptedString(from value: String?) throws -> String? {
            guard
                let value = value,
                let encryptedData = Data(base64Encoded: value),
                let decryptedData = try decrypt(encryptedData)
            else {
                return nil
            }
            return String(data: decryptedData, encoding: .utf8)
        }

        var id = id
        var email = email
        var name = name
        var extensions = extensions
        var stillEncrypted: [String] = []

        for field in encrypted.removingDuplicates() {
            switch field {
            case "id":
                if let value = try decryptedString(from: id) {
                    id = value
                    continue
                }
            case "email":
                if let value = try decryptedString(from: email) {
                    email = value
                    continue
                }
            case "name":
                if let value = try decryptedString(from: name) {
                    name = value
                    continue
                }
            default:
                if let value = try decryptedString(from: extensions[field]?.string) {
                    extensions[field] = .string(value)
                    continue
                }
            }
            stillEncrypted.append(field)
        }

        return User(
            id: id,
            email: email,
            name: name,
            extensions: extensions,
            encrypted: stillEncrypted
        )
    }
}
