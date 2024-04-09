//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import UIKit

final class DeviceService {
    private let repository: DeviceRepository
    private let httpClient: HTTPClient

    init(repository: DeviceRepository, httpClient: HTTPClient) {
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

    // Returns the device's name.
    var name: String {
        UIDevice.current.name
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
    func registerLicense(_ license: LicenseDocument, at link: Link) -> Deferred<Data?, Error> {
        deferredCatching {
            let registered = try self.repository.isDeviceRegistered(for: license)
            guard !registered else {
                return .success(nil)
            }
            guard let url = link.url(with: self.asQueryParameters) else {
                throw LCPError.licenseInteractionNotAvailable
            }

            return self.httpClient.fetch(HTTPRequest(url: url, method: .post))
                .tryMap { response in
                    guard 100 ..< 400 ~= response.statusCode else {
                        return nil
                    }

                    try self.repository.registerDevice(for: license)
                    return response.body
                }
        }
    }
}
