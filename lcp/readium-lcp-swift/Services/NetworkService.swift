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

// When true, will show the requests made from the Network service in the console.
private let DEBUG = false


final class NetworkService {
    
    typealias Response = (status: Int, data: Data)
    
    enum Method: String {
        case get = "GET"
        case post = "POST"
    }
    
    func makeURL(_ link: Link, parameters: [String: CustomStringConvertible]) -> URL? {
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
    
    func fetch(_ url: URL, method: Method = .get, _ completion: @escaping (Result<Response>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if (DEBUG) { print("#network \(method.rawValue) \(url)") }
        
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
    
}
