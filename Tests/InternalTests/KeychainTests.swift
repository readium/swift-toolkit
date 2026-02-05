//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumInternal
import Testing

// FIXME: Keychain testing require an host application with entitlements.
/*
 @Suite struct KeychainTests {
     let keychain: Keychain
     let testServiceName = "org.readium.lcp.test.keychain-helper"

     init() throws {
         keychain = Keychain(
             serviceName: testServiceName,
             synchronizable: false
         )
         // Clean up any existing test data
         try? keychain.deleteAll()
     }

     // MARK: - Save Tests

     @Test func saveData() throws {
         defer { try? keychain.deleteAll() }

         let testData = "Test Value".data(using: .utf8)!
         try keychain.save(data: testData, forKey: "test-key")

         let retrieved = try keychain.load(forKey: "test-key")
         #expect(retrieved == testData)
     }

     @Test func saveDuplicateKeyThrowsError() throws {
         defer { try? keychain.deleteAll() }

         let testData = "Test Value".data(using: .utf8)!
         try keychain.save(data: testData, forKey: "duplicate-key")

         #expect(throws: KeychainError.self) {
             try keychain.save(data: testData, forKey: "duplicate-key")
         }
     }

     @Test func saveMultipleKeys() throws {
         defer { try? keychain.deleteAll() }

         let data1 = "Value 1".data(using: .utf8)!
         let data2 = "Value 2".data(using: .utf8)!
         let data3 = "Value 3".data(using: .utf8)!

         try keychain.save(data: data1, forKey: "key1")
         try keychain.save(data: data2, forKey: "key2")
         try keychain.save(data: data3, forKey: "key3")

         let loaded1 = try keychain.load(forKey: "key1")
         let loaded2 = try keychain.load(forKey: "key2")
         let loaded3 = try keychain.load(forKey: "key3")
         #expect(loaded1 == data1)
         #expect(loaded2 == data2)
         #expect(loaded3 == data3)
     }

     // MARK: - Load Tests

     @Test func loadNonExistentKeyReturnsNil() throws {
         defer { try? keychain.deleteAll() }

         let result = try keychain.load(forKey: "non-existent")
         #expect(result == nil)
     }

     @Test func loadAfterSave() throws {
         defer { try? keychain.deleteAll() }

         let testData = "Persistent Value".data(using: .utf8)!
         try keychain.save(data: testData, forKey: "persistent-key")

         let loaded = try keychain.load(forKey: "persistent-key")
         #expect(loaded == testData)
     }

     // MARK: - Update Tests

     @Test func updateExistingKey() throws {
         defer { try? keychain.deleteAll() }

         let originalData = "Original".data(using: .utf8)!
         let updatedData = "Updated".data(using: .utf8)!

         try keychain.save(data: originalData, forKey: "update-key")
         try keychain.update(data: updatedData, forKey: "update-key")

         let result = try keychain.load(forKey: "update-key")
         #expect(result == updatedData)
     }

     @Test func updateNonExistentKeyThrowsError() throws {
         defer { try? keychain.deleteAll() }

         let testData = "Test".data(using: .utf8)!

         #expect(throws: KeychainError.self) {
             try keychain.update(data: testData, forKey: "non-existent")
         }
     }

     // MARK: - Delete Tests

     @Test func deleteExistingKey() throws {
         defer { try? keychain.deleteAll() }

         let testData = "Delete Me".data(using: .utf8)!
         try keychain.save(data: testData, forKey: "delete-key")

         try keychain.delete(forKey: "delete-key")

         let result = try keychain.load(forKey: "delete-key")
         #expect(result == nil)
     }

     @Test func deleteNonExistentKeyDoesNotThrow() throws {
         defer { try? keychain.deleteAll() }

         // Should not throw an error
         #expect(throws: Never.self) {
             try keychain.delete(forKey: "non-existent")
         }
     }

     // MARK: - DeleteAll Tests

     @Test func deleteAll() throws {
         defer { try? keychain.deleteAll() }

         let data1 = "Value 1".data(using: .utf8)!
         let data2 = "Value 2".data(using: .utf8)!
         let data3 = "Value 3".data(using: .utf8)!

         try keychain.save(data: data1, forKey: "key1")
         try keychain.save(data: data2, forKey: "key2")
         try keychain.save(data: data3, forKey: "key3")

         try keychain.deleteAll()

         let loaded1 = try keychain.load(forKey: "key1")
         let loaded2 = try keychain.load(forKey: "key2")
         let loaded3 = try keychain.load(forKey: "key3")
         #expect(loaded1 == nil)
         #expect(loaded2 == nil)
         #expect(loaded3 == nil)
     }

     @Test func deleteAllWithNoItemsDoesNotThrow() throws {
         #expect(throws: Never.self) {
             try keychain.deleteAll()
         }
     }

     // MARK: - AllKeys Tests

     @Test func allKeysEmpty() throws {
         defer { try? keychain.deleteAll() }

         let keys = try keychain.allKeys()
         #expect(keys.isEmpty)
     }

     @Test func allKeysReturnsSavedKeys() throws {
         defer { try? keychain.deleteAll() }

         let data = "Test".data(using: .utf8)!
         try keychain.save(data: data, forKey: "key1")
         try keychain.save(data: data, forKey: "key2")
         try keychain.save(data: data, forKey: "key3")

         let keys = try keychain.allKeys()
         #expect(Set(keys) == Set(["key1", "key2", "key3"]))
     }

     // MARK: - AllItems Tests

     @Test func allItemsEmpty() throws {
         defer { try? keychain.deleteAll() }

         let items = try keychain.allItems()
         #expect(items.isEmpty)
     }

     @Test func allItemsReturnsSavedData() throws {
         defer { try? keychain.deleteAll() }

         let data1 = "Value 1".data(using: .utf8)!
         let data2 = "Value 2".data(using: .utf8)!

         try keychain.save(data: data1, forKey: "key1")
         try keychain.save(data: data2, forKey: "key2")

         let items = try keychain.allItems()
         #expect(items.count == 2)
         #expect(items["key1"] == data1)
         #expect(items["key2"] == data2)
     }

     // MARK: - Service Isolation Tests

     @Test func serviceIsolation() throws {
         // Create two keychains with different service names
         let keychain1 = Keychain(
             serviceName: "org.readium.lcp.test.service1",
             synchronizable: false
         )
         let keychain2 = Keychain(
             serviceName: "org.readium.lcp.test.service2",
             synchronizable: false
         )

         defer {
             try? keychain1.deleteAll()
             try? keychain2.deleteAll()
         }

         let data = "Test".data(using: .utf8)!
         try keychain1.save(data: data, forKey: "shared-key")

         // keychain2 should not see the data from keychain1
         let loaded = try keychain2.load(forKey: "shared-key")
         #expect(loaded == nil)
     }
 }
 */
