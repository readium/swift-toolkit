//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

final class DeviceService {
    private let repository: LCPLicenseRepository
    private let httpClient: HTTPClient

    /// Returns the device's name.
    let name: String
    /// Returns the device's ID
    let id: String

    init(
        deviceName: String,
        deviceId: String?,
        repository: LCPLicenseRepository,
        httpClient: HTTPClient
    ) {
        name = deviceName

        if let providedId = deviceId {
            id = providedId
        } else if let savedId = UserDefaults.standard.string(forKey: "lcp_device_id") {
            id = savedId
        } else {
            let generatedId = UUID().uuidString
            UserDefaults.standard.set(generatedId, forKey: "lcp_device_id")
            id = generatedId
        }

        self.repository = repository
        self.httpClient = httpClient
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
