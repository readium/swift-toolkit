//
//  DeviceService.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 07.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared

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
        return UIDevice.current.name
    }
    
    // Device ID and name as query parameters for HTTP requests.
    var asQueryParameters: [String: String] {
        return [
            "id": id,
            "name": name
        ]
    }
    
    /// Registers the device for the given license.
    /// If the call was made, the updated Status Document data is given to the completion closure.
    @discardableResult
    func registerLicense(_ license: LicenseDocument, at link: Link) -> Deferred<Data?, Error> {
        return deferredCatching {
            let registered = try self.repository.isDeviceRegistered(for: license)
            guard !registered else {
                return .success(nil)
            }
            guard let url = link.url(with: self.asQueryParameters) else {
                throw LCPError.licenseInteractionNotAvailable
            }
            
            return self.httpClient.fetch(HTTPRequest(url: url, method: .post))
                .tryMap { response in
                    guard 100..<400 ~= response.statusCode else {
                        return nil
                    }
                    
                    try self.repository.registerDevice(for: license)
                    return response.body
                }
        }
    }
    
}
