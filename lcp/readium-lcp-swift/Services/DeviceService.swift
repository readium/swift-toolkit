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

final class DeviceService {
    
    private let repository: DeviceRepository
    
    init(repository: DeviceRepository) {
        self.repository = repository
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
    
    /// Registers the device for the given license.
    /// If the call was made, the updated Status Document data is given to the completion closure.
    /// - Returns: Whether the device was already registered.
    @discardableResult
    func registerLicense(_ license: LicenseDocument, using status: StatusDocument, completion: ((Result<Data?>) -> Void)? = nil) -> Bool {
        guard let registered = try? repository.isDeviceRegistered(for: license), !registered else {
            completion?(.success(nil))
            return true
        }
        
        // Removing the template {?id,name}
        // FIXME: this might fail if the server doesn't use strictly {?id,name}, but for example {?name,id}
        guard let href = status.link(withRel: .register)?.href.absoluteString.replacingOccurrences(of: "%7B?id,name%7D", with: ""),
            var urlBuilder = URLComponents(string: href)
            else {
                completion?(.failure(.registerLinkNotFound))
                return true
        }

        urlBuilder.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "name", value: name)
        ]
        
        guard let url = urlBuilder.url else {
            completion?(.failure(.registerLinkNotFound))
            return true
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                completion?(.failure(.registrationFailure))
                return
            }
            
            do {
                try self.repository.registerDevice(for: license)
                completion?(.success(data))
            } catch {
                completion?(.failure(.registrationFailure))
            }
        }.resume()
        
        return false
    }

}
