//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Security

/// Errors occurring in ``Keychain``.
public enum KeychainError: Error {
    /// The item was not found in the Keychain.
    case itemNotFound

    /// An item with this key already exists.
    case duplicateItem

    /// The data retrieved from the Keychain is invalid.
    case invalidData

    /// An unhandled Keychain error occurred.
    case unhandledError(OSStatus)
}

/// Utility for managing Keychain operations.
///
/// This class handles low-level Security framework calls for storing, retrieving,
/// updating, and deleting data from the iOS/macOS Keychain.
public final class Keychain {
    private let serviceName: String
    private let synchronizable: Bool

    /// Initializes a ``Keychain`` with the specified configuration.
    ///
    /// - Parameters:
    ///   - serviceName: The service identifier for Keychain items.
    ///   - synchronizable: Whether items should sync via iCloud Keychain.
    public init(
        serviceName: String,
        synchronizable: Bool = true
    ) {
        self.serviceName = serviceName
        self.synchronizable = synchronizable
    }

    /// Saves data to the Keychain with the specified key.
    ///
    /// - Parameters:
    ///   - data: The data to save.
    ///   - key: The account identifier.
    public func save(data: Data, forKey key: String) throws (KeychainError) {
        var query = baseQuery(forKey: key, forAdding: true)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw mapError(status)
        }
    }

    /// Loads data from the Keychain for the specified key.
    ///
    /// - Parameter key: The account identifier.
    /// - Returns: The data if found, or `nil` if no item exists with this key.
    public func load(forKey key: String) throws (KeychainError) -> Data? {
        var query = baseQuery(forKey: key, forAdding: false)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw mapError(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    /// Updates existing data in the Keychain for the specified key.
    ///
    /// - Parameters:
    ///   - data: The new data to save.
    ///   - key: The account identifier.
    public func update(data: Data, forKey key: String) throws (KeychainError) {
        let query = baseQuery(forKey: key, forAdding: false)
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        guard status == errSecSuccess else {
            throw mapError(status)
        }
    }

    /// Deletes an item from the Keychain for the specified key.
    ///
    /// - Parameter key: The account identifier.
    public func delete(forKey key: String) throws (KeychainError) {
        let query = baseQuery(forKey: key, forAdding: false)
        let status = SecItemDelete(query as CFDictionary)

        // Success or item not found are both acceptable
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw mapError(status)
        }
    }

    /// Deletes all items for this service from the Keychain.
    public func deleteAll() throws (KeychainError) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw mapError(status)
        }
    }

    /// Returns all account identifiers (keys) stored for this service.
    ///
    /// - Returns: An array of account identifiers.
    public func allKeys() throws (KeychainError) -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess else {
            throw mapError(status)
        }

        guard let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    /// Returns all items stored for this service.
    ///
    /// - Returns: A dictionary where keys are account identifiers and values are
    ///   the stored data.
    public func allItems() throws (KeychainError) -> [String: Data] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return [:]
        }

        guard status == errSecSuccess else {
            throw mapError(status)
        }

        guard let items = result as? [[String: Any]] else {
            return [:]
        }

        var itemsDictionary: [String: Data] = [:]
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               let data = item[kSecValueData as String] as? Data
            {
                itemsDictionary[account] = data
            }
        }

        return itemsDictionary
    }

    // MARK: - Private Helpers

    /// Creates the base query dictionary for Keychain operations.
    ///
    /// - Parameters:
    ///   - key: The account identifier.
    ///   - forAdding: If `true`, uses the boolean `synchronizable` value for adding items.
    ///     If `false`, uses `kSecAttrSynchronizableAny` for queries/updates/deletes.
    private func baseQuery(forKey key: String, forAdding: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        if forAdding {
            query[kSecAttrSynchronizable as String] = synchronizable
        } else {
            query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        }

        return query
    }

    /// Maps OSStatus error codes to KeychainError cases.
    private func mapError(_ status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:
            return .itemNotFound
        case errSecDuplicateItem:
            return .duplicateItem
        default:
            return .unhandledError(status)
        }
    }
}
