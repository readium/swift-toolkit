//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP
import ReadiumShared
import Testing

/// Serialized because the legacy migration path reads a process-global
/// `UserDefaults` key, which would race with the fresh-state test if run in
/// parallel.
@Suite(.serialized)
struct DeviceServiceTests {
    /// Unique Keychain service name so each test run is isolated from the real
    /// device store and from previous runs.
    private let serviceName = "org.readium.lcp.device.test.\(UUID().uuidString)"

    private func keychain() -> Keychain {
        Keychain(serviceName: serviceName, synchronizable: false)
    }

    private func loadStoredID() throws -> String? {
        try keychain()
            .load(forKey: DeviceService.deviceIDKeychainAccount)
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    private func makeService(deviceId: String? = nil) -> DeviceService {
        DeviceService(
            deviceName: "Test Device",
            deviceId: deviceId,
            repository: InMemoryLCPLicenseRepository(),
            httpClient: DefaultHTTPClient(),
            keychainServiceName: serviceName
        )
    }

    @Test func generatesAndPersistsAcrossInstances() {
        defer { try? keychain().deleteAll() }

        // A fresh state generates a new ID...
        let first = makeService()
        #expect(first.id != nil)

        // ...which is reused by a second service (persisted in the Keychain).
        let second = makeService()
        #expect(second.id == first.id)
    }

    @Test func migratesLegacyUserDefaultsValue() throws {
        defer {
            try? keychain().deleteAll()
            UserDefaults.standard.removeObject(forKey: DeviceService.legacyDeviceIDDefaultsKey)
        }

        // A legacy ID is present in UserDefaults and the Keychain is empty.
        let legacyID = "legacy-\(UUID().uuidString)"
        UserDefaults.standard.set(legacyID, forKey: DeviceService.legacyDeviceIDDefaultsKey)

        // The legacy value is returned...
        let service = makeService()
        #expect(service.id == legacyID)

        // ...and migrated to the Keychain.
        #expect(try loadStoredID() == legacyID)
    }

    @Test func usesProvidedIDWithoutTouchingKeychain() throws {
        defer { try? keychain().deleteAll() }

        let service = makeService(deviceId: "app-provided-id")
        #expect(service.id == "app-provided-id")

        // The Keychain is untouched.
        #expect(try loadStoredID() == nil)
    }
}
