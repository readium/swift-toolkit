//
//  NetworkService.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 08.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


final class NetworkService: Loggable {

    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }
    
    func fetch(_ url: URL, method: Method = .get, timeout: TimeInterval? = nil) -> Deferred<(status: Int, data: Data), Error> {
        return deferred { success, failure, _ in
            self.log(.info, "\(method.rawValue) \(url)")
    
            var request = URLRequest(url: url)
            request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
            request.httpMethod = method.rawValue
            if let timeout = timeout {
                request.timeoutInterval = timeout
            }
    
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard
                    let status = (response as? HTTPURLResponse)?.statusCode,
                    let data = data else
                {
                    failure(LCPError.network(error))
                    return
                }
    
                success((status, data))
            }.resume()
        }
    }

    func download(_ url: URL, title: String? = nil, completion: @escaping (Result<(file: URL, task: URLSessionDownloadTask?), Error>) -> Void) -> (task: URLSessionDownloadTask, progress: Observable<DownloadProgress>) {
        self.log(.info, "download \(url)")

        let request = URLRequest(url: url)
        return DownloadSession.shared.launchTask(request: request, description: title) { tmpLocalURL, response, error, downloadTask in
            guard let file = tmpLocalURL, error == nil else {
                completion(.failure(LCPError.network(error)))
                return false
            }

            completion(.success((file, downloadTask)))
            return true
        }
    }
    
    /// Builds a more meaningful User-Agent for the LCP network requests.
    /// See. https://github.com/readium/r2-testapp-swift/issues/291
    private lazy var userAgent: String = {
        var sysinfo = utsname()
        uname(&sysinfo)

        let darwinVersion = String(bytes: Data(bytes: &sysinfo.release, count: Int(_SYS_NAMELEN)), encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            ?? "0"

        let deviceName = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            ?? "0"

        let cfNetworkVersion = Bundle(identifier: "com.apple.CFNetwork")?
            .infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0"

        let appInfo = Bundle.main.infoDictionary
        let appName = appInfo?["CFBundleName"] as? String ?? "Unknown App"
        let appVersion = appInfo?["CFBundleShortVersionString"] as? String ?? "0"
        let device = UIDevice.current

        return "\(appName)/\(appVersion) \(deviceName) \(device.systemName)/\(device.systemVersion) CFNetwork/\(cfNetworkVersion) Darwin/\(darwinVersion)"
    }()
    
}
