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
private let DEBUG = false


final class NetworkService {
    
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }
    
    func makeURL(_ link: Link, parameters: [String: CustomStringConvertible] = [:]) -> URL? {
        let templated = (link.templated ?? false)
        return makeURL(link.href, templated: templated, parameters: parameters)
    }
    
    func makeURL(_ url: URL, templated: Bool = false, parameters: [String: CustomStringConvertible] = [:]) -> URL? {
        if !templated && parameters.isEmpty {
            return url
        }
        return makeURL(url.absoluteString, templated: templated, parameters: parameters)
    }
    
    func makeURL(_ urlString: String, templated: Bool = false, parameters: [String: CustomStringConvertible] = [:]) -> URL? {
        var urlString = urlString
        if templated {
            // Quick hack to remove the templating info (eg. {?id,name})
            // Should probably use an actual templating framework to replace the parameters propertly.
            urlString = urlString.replacingOccurrences(of: "%7B\\?.+?\\%7D", with: "", options: [.regularExpression])
        }
        
        guard var urlBuilder = URLComponents(string: urlString) else {
            return nil
        }

        urlBuilder.queryItems = parameters.map { param in
            URLQueryItem(name: param.key, value: param.value.description)
        }

        return urlBuilder.url
    }
    
    func fetch(_ url: URL, method: Method = .get, _ completion: @escaping (Result<(status: Int, data: Data)>) -> Void) {
        if (DEBUG) { print("#network \(method.rawValue) \(url)") }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let status = (response as? HTTPURLResponse)?.statusCode,
                let data = data
                else {
                    completion(.failure(.network(error)))
                    return
            }
            
            completion(.success((status, data)))
        }.resume()
    }
    
    func download(_ url: URL, description: String?, _ completion: @escaping (Result<(file: URL, task: URLSessionDownloadTask?)>) -> Void) {
        if (DEBUG) { print("#network download \(url)") }
        
        let request = URLRequest(url: url)
        DownloadSession.shared.launch(request: request, description: description) { tmpLocalURL, response, error, downloadTask in
            guard let file = tmpLocalURL, error == nil else {
                completion(.failure(.network(error)))
                return false
            }

            completion(.success((file, downloadTask)))
            return true
        }
    }
    
}
