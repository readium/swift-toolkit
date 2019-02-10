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

// When true, will show the requests made from the Network service in the console.
private let DEBUG = true


final class NetworkService {
    
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }
    
    /// Applies a set of parameters to a templated URL.
    /// eg. http://url?{id,name} + [id: x, name: y] -> http://url?id=x&name=y
    /// There's a quick hack to remove the templating info, we shoud probably use an actual templating library to replace the parameters propertly.
    func urlFromLink(_ link: Link, context: [String: CustomStringConvertible] = [:]) -> URL? {
        guard (link.templated ?? false) else {
            // No-op if the URL is not templated
            return link.href
        }

        let urlString = link.href.absoluteString
            .replacingOccurrences(of: "%7B\\?.+?\\%7D", with: "", options: [.regularExpression])

        guard var urlBuilder = URLComponents(string: urlString) else {
            return nil
        }
        
        // Add the template context as query parameters
        urlBuilder.queryItems = context.map { param in
            URLQueryItem(name: param.key, value: param.value.description)
        }

        return urlBuilder.url
    }
    
    func fetch(_ url: URL, method: Method = .get) -> Deferred<(status: Int, data: Data)> {
        return Deferred { success, failure in
            if (DEBUG) { print("#network \(method.rawValue) \(url)") }
    
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

    func download(_ url: URL, description: String?) -> Deferred<(file: URL, task: URLSessionDownloadTask?)> {
        return Deferred { success, failure in
            if (DEBUG) { print("#network download \(url)") }
    
            let request = URLRequest(url: url)
            DownloadSession.shared.launch(request: request, description: description) { tmpLocalURL, response, error, downloadTask in
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
