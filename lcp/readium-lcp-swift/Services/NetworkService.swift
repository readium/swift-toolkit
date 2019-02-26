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
import R2Shared


final class NetworkService: Loggable {
    
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }

    func fetch(_ url: URL, method: Method = .get) -> Deferred<(status: Int, data: Data)> {
        return Deferred { success, failure in
            self.log(.info, "\(method.rawValue) \(url)")
    
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
    
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let status = (response as? HTTPURLResponse)?.statusCode,
                    let data = data
                    else {
                        failure(LCPError.network(error))
                        return
                }
    
                success((status, data))
            }.resume()
        }
    }

    func download(_ url: URL, title: String? = nil) -> Deferred<(file: URL, task: URLSessionDownloadTask?)> {
        return Deferred { success, failure in
            self.log(.info, "download \(url)")
    
            let request = URLRequest(url: url)
            DownloadSession.shared.launch(request: request, description: title) { tmpLocalURL, response, error, downloadTask in
                guard let file = tmpLocalURL, error == nil else {
                    failure(LCPError.network(error))
                    return false
                }

                success((file, downloadTask))
                return true
            }
        }
    }
    
}
