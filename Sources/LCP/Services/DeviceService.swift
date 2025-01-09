//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

final class DeviceService {
    private let repository: LCPLicenseRepository
    private let httpClient: HTTPClient

    /// Returns the device's name.
    var name: String

    init(
        deviceName: String,
        repository: LCPLicenseRepository,
        httpClient: HTTPClient
    ) {
        name = deviceName
        self.repository = repository
        self.httpClient = httpClient
    }

    /// Returns the device ID, creates it if needed.
    var id: String {
        let defaults = UserDefaults.standard
        guard let deviceId = defaults.string(forKey: "lcp_device_id") else {
            let deviceId = UUID().description
            defaults.set(deviceId.description, forKey: "lcp_device_id")
            return deviceId.description
        }
        return deviceId
    }

    // Device ID and name as query parameters for HTTP requests.
    var asQueryParameters: [String: String] {
        [
            "id": id,
            "name": name,
        ]
    }

    /// Registers the device for the given license.
    /// If the call was made, the updated Status Document data is given to the completion closure.
    @discardableResult
    func registerLicense(_ license: LicenseDocument, at link: Link) async throws -> Data? {
        let registered = try await repository.isDeviceRegistered(for: license.id)
        guard !registered else {
            return nil
        }
        guard let url = link.url(parameters: asQueryParameters) else {
            throw LCPError.licenseInteractionNotAvailable
        }

        let data = await httpClient.fetch(HTTPRequest(url: url, method: .post))
            .map(\.body)

        try await repository.registerDevice(for: license.id)

        return try data.get()
    }
}
