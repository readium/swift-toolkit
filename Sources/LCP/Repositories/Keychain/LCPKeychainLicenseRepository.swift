//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Errors occurring in ``LCPKeychainLicenseRepository``.
public enum LCPKeychainLicenseRepositoryError: Error {
    /// The license with the given `id` was not found in the repository.
    case licenseNotFound(id: LicenseDocument.ID)

    /// An error occurred while accessing the keychain.
    case keychain(KeychainError)

    /// An error occurred while decoding or encoding a License.
    case coding(Error)
}

/// Keychain-based implementation of ``LCPLicenseRepository``.
///
/// Stores license data securely in the iOS/macOS Keychain with optional iCloud
/// synchronization.
public actor LCPKeychainLicenseRepository: LCPLicenseRepository, Loggable {
    /// Internal data structure for storing license information in the Keychain.
    private struct License: Codable {
        /// Unique identifier for this license.
        let licenseID: LicenseDocument.ID

        /// JSON representation of the ``LicenseDocument``.
        var licenseJSON: String?

        /// Remaining pages to print.
        var printsLeft: Int?

        /// Remaining number of characters to copy.
        var copiesLeft: Int?

        /// Date when the device was registered for this license.
        var registered: Bool

        /// Date this license was added to the Keychain.
        let created: Date

        /// Date this license was updated in the Keychain.
        var updated: Date
    }

    private let keychain: Keychain
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Initializes a Keychain-based license repository.
    ///
    /// - Parameters:
    ///   - synchronizable: Whether items should sync via iCloud Keychain.
    public init(synchronizable: Bool = true) {
        keychain = Keychain(
            serviceName: "org.readium.lcp.licenses",
            synchronizable: synchronizable
        )

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - LCPLicenseRepository

    public func addLicense(_ licenseDocument: LicenseDocument) async throws {
        if var license = try getLicense(for: licenseDocument.id) {
            // License exists - update it without overwriting consumable rights
            license.licenseJSON = licenseDocument.jsonString
            try updateLicense(license, for: licenseDocument.id)

        } else {
            // New license - initialize with rights from license document
            let newLicense = License(
                licenseID: licenseDocument.id,
                licenseJSON: licenseDocument.jsonString,
                printsLeft: licenseDocument.rights.print,
                copiesLeft: licenseDocument.rights.copy,
                registered: false,
                created: Date(),
                updated: Date()
            )

            try addLicense(newLicense, for: licenseDocument.id)
        }
    }

    public func license(for id: LicenseDocument.ID) async throws -> LicenseDocument? {
        guard
            let licenseData = try getLicense(for: id),
            let jsonString = licenseData.licenseJSON,
            let jsonData = jsonString.data(using: .utf8),
            let licenseDocument = try? LicenseDocument(data: jsonData)
        else {
            return nil
        }

        return licenseDocument
    }

    public func isDeviceRegistered(for id: LicenseDocument.ID) async throws -> Bool {
        try requireLicense(for: id).registered
    }

    public func registerDevice(for id: LicenseDocument.ID) async throws {
        var license = try requireLicense(for: id)
        license.registered = true
        try updateLicense(license, for: id)
    }

    public func userRights(for id: LicenseDocument.ID) async throws -> LCPConsumableUserRights {
        guard let licenseData = try getLicense(for: id) else {
            throw LCPKeychainLicenseRepositoryError.licenseNotFound(id: id)
        }

        return LCPConsumableUserRights(
            print: licenseData.printsLeft,
            copy: licenseData.copiesLeft
        )
    }

    public func updateUserRights(
        for id: LicenseDocument.ID,
        with changes: (inout LCPConsumableUserRights) -> Void
    ) async throws {
        var license = try requireLicense(for: id)

        // Get current rights
        var currentRights = LCPConsumableUserRights(
            print: license.printsLeft,
            copy: license.copiesLeft
        )

        // Apply changes
        changes(&currentRights)

        // Update the data
        license.printsLeft = currentRights.print
        license.copiesLeft = currentRights.copy

        try updateLicense(license, for: id)
    }

    // MARK: - Migration Support

    /// Imports license rights from an external source without requiring the
    /// full ``LicenseDocument``.
    ///
    /// This is used during migration from repositories that don't store the
    /// full document, like the legacy SQLite repositories.
    ///
    /// When the publication is later opened, `addLicense()` will add the full
    /// document while preserving these migrated rights.
    ///
    /// - Parameters:
    ///   - licenseID: The license identifier
    ///   - rights: The consumable user rights to store
    ///   - registered: Whether the device is registered for this license
    public func importLicenseRights(
        for licenseID: LicenseDocument.ID,
        rights: LCPConsumableUserRights,
        registered: Bool
    ) throws {
        // We don't overwrite the rights if the license already exists.
        guard try getLicense(for: licenseID) == nil else {
            return
        }

        // Create new entry without the full license document, which will
        // be added when the publication is opened again.
        let newData = License(
            licenseID: licenseID,
            licenseJSON: nil,
            printsLeft: rights.print,
            copiesLeft: rights.copy,
            registered: registered,
            created: Date(),
            updated: Date()
        )
        try addLicense(newData, for: licenseID)
    }

    // MARK: - Keychain Access

    private func requireLicense(for licenseID: LicenseDocument.ID) throws (LCPKeychainLicenseRepositoryError) -> License {
        guard let license = try getLicense(for: licenseID) else {
            throw .licenseNotFound(id: licenseID)
        }
        return license
    }

    /// Gets a license from the Keychain for the given license ID.
    private func getLicense(for licenseID: LicenseDocument.ID) throws (LCPKeychainLicenseRepositoryError) -> License? {
        guard let data = try getFromKeychain(id: licenseID) else {
            return nil
        }

        return try decode(data)
    }

    /// Adds a new license to the Keychain.
    private func addLicense(_ license: License, for id: LicenseDocument.ID) throws (LCPKeychainLicenseRepositoryError) {
        try addToKeychain(data: encode(license), for: id)
    }

    /// Updates an existing license in the Keychain.
    private func updateLicense(_ license: License, for id: LicenseDocument.ID) throws (LCPKeychainLicenseRepositoryError) {
        var license = license
        license.updated = Date()
        let data = try encode(license)
        try updateKeychain(data: data, for: id)
    }

    // MARK: - Low-Level Helpers

    private func getFromKeychain(id: LicenseDocument.ID) throws (LCPKeychainLicenseRepositoryError) -> Data? {
        do {
            return try keychain.load(forKey: id)
        } catch {
            throw .keychain(error)
        }
    }

    private func addToKeychain(data: Data, for id: LicenseDocument.ID) throws (LCPKeychainLicenseRepositoryError) {
        do {
            try keychain.save(data: data, forKey: id)
        } catch {
            throw .keychain(error)
        }
    }

    private func updateKeychain(data: Data, for id: LicenseDocument.ID) throws (LCPKeychainLicenseRepositoryError) {
        do {
            try keychain.update(data: data, forKey: id)
        } catch {
            throw .keychain(error)
        }
    }

    private func decode(_ data: Data) throws (LCPKeychainLicenseRepositoryError) -> License {
        do {
            return try decoder.decode(License.self, from: data)
        } catch {
            throw .coding(error)
        }
    }

    private func encode(_ license: License) throws (LCPKeychainLicenseRepositoryError) -> Data {
        do {
            return try encoder.encode(license)
        } catch {
            throw .coding(error)
        }
    }
}
