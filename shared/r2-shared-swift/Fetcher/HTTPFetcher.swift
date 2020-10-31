//
//  HTTPFetcher.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Fetches remote resources with HTTP.
public final class HTTPFetcher: Fetcher {
    
    enum Error: Swift.Error {
        case invalidURL(String)
        case serverFailure
    }

    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }
    
    public let links: [Link] = []
    
    public func get(_ link: Link) -> Resource {
        guard let url = url(for: link.href) else {
            return FailureResource(link: link, error: .other(Error.invalidURL(link.href)))
        }
        return HTTPResource(link: link, url: url)
    }
    
    public func close() { }

    /// Base URL from which relative HREF are served.
    private let baseURL: URL?
    
    private func url(for href: String) -> URL? {
        // HREF relative to the baseURL.
        if href.hasPrefix("/"), let baseURL = baseURL {
            return baseURL.appendingPathComponent(href)
        }
        
        // Absolute URL.
        if
            let url = URL(string: href),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        {
            return url
        }
        
        return nil
    }
    
    final class HTTPResource: Resource {

        let link: Link
        
        let file: URL? = nil
        
        private let url: URL
        
        private var cachedHeadResponse: HTTPURLResponse?
        
        private var headResponse: ResourceResult<HTTPURLResponse> {
            if let response = cachedHeadResponse {
                return .success(response)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            return URLSession.shared.synchronousDataTask(with: request)
                .map { [unowned self] data, response in
                    self.cachedHeadResponse = response
                    return response
                }
        }
        
        var length: ResourceResult<UInt64> {
            headResponse.flatMap {
                let length = $0.expectedContentLength
                if length < 0 {
                    return .failure(.unavailable)
                } else {
                    return .success(UInt64(length))
                }
            }
        }

        init(link: Link, url: URL) {
            self.link = link
            self.url = url
        }
        
        func read(range: Range<UInt64>?) -> ResourceResult<Data> {
            // FIXME:
            return .failure(.unavailable)
//            if let range = range {
//                return headResponse.flatMap { response in
//                    var request = URLRequest(url: url)
//                    if response.acceptsRanges {
//                        request.setBytesRange(range)
//                    }
//                    return URLSession.shared.synchronousDataTask(with: request)
//                        .map { data, _ in data }
//                }
//
//            } else {
//                let request = URLRequest(url: url)
//                return URLSession.shared.synchronousDataTask(with: request)
//                    .map { data, _ in data }
//            }
        }
        
        func close() { }
        
    }

}

private extension URLSession {
    
    func synchronousDataTask(with request: URLRequest) -> ResourceResult<(Data, HTTPURLResponse)> {
        var data: Data?
        var response: URLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)
        let dataTask = self.dataTask(with: request) {
            data = $0
            response = $1
            error = $2
            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)
        
        if let response = response as? HTTPURLResponse {
            if let data = data, response.statusCode == 200 {
                return .success((data, response))
            } else {
                return .failure({
                    switch response.statusCode {
                    case 403:
                        return .forbidden
                    case 404:
                        return .notFound
                    case 503:
                        return .unavailable
                    default:
                        return .other(HTTPFetcher.Error.serverFailure)
                    }
                }())
            }
        } else {
            return .failure(.other(error ?? HTTPFetcher.Error.serverFailure))
        }
    }
    
}

private extension HTTPURLResponse {
    
    func value(forHTTPHeaderField field: String) -> String? {
        return allHeaderFields[field] as? String
    }
    
    var acceptsRanges: Bool {
        let header = value(forHTTPHeaderField: "Accept-Ranges")
        return header != nil && header != "none"
    }
    
}

private extension URLRequest {
    
    mutating func setBytesRange(_ range: Range<UInt64>) {
        addValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
    }
    
}
