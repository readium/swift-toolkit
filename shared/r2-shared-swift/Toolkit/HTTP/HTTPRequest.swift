//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds the information about an HTTP request performed by an `HTTPClient`.
public struct HTTPRequest: Equatable {

    /// Address of the remote resource to request.
    public var url: URL

    /// HTTP method to use for the request.
    public var method: Method

    /// Supported HTTP methods.
    public enum Method: String, Equatable {
        case delete = "DELETE"
        case get = "GET"
        case head = "HEAD"
        case options = "OPTIONS"
        case patch = "PATCH"
        case post = "POST"
        case put = "PUT"
    }

    /// Additional HTTP headers to use.
    public var headers: [String: String]

    /// The data sent as the message body of a request, such as for an HTTP POST request.
    public var body: Body?

    /// Supported body values.
    public enum Body: Equatable {
        case data(Data)
        case file(URL)
    }

    /// The timeout interval of the request.
    public var timeoutInterval: TimeInterval?

    /// If true, the user might be presented with interactive dialogs, such as popping up an authentication dialog.
    public var allowUserInteraction: Bool

    /// Additional context data specific to a given implementation of `HTTPClient`.
    public var userInfo: [AnyHashable: AnyHashable]

    public init(
        url: URL,
        method: Method = .get,
        headers: [String: String] = [:],
        body: Body? = nil,
        timeoutInterval: TimeInterval? = nil,
        allowUserInteraction: Bool = false,
        userInfo: [AnyHashable: AnyHashable] = [:]
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.allowUserInteraction = allowUserInteraction
        self.userInfo = userInfo
    }

    /// Issue a byte range request. Use -1 to download until the end.
    public mutating func setRange(_ range: Range<UInt64>) {
        let start = max(0, range.lowerBound)
        var value = "\(start)-"
        if (range.upperBound >= start) {
            value += "\(range.upperBound)"
        }
        headers["Range"] = "bytes=\(value)"
    }

    /// Returns whether this request has the HTTP header with the given `key`, without taking into account the case.
    public func hasHeader(_ name: String) -> Bool {
        let name = name.lowercased()
        return headers.contains { n, _ in n.lowercased() == name }
    }

    /// Initializes a POST request with the given form data.
    public mutating func setPOSTForm(_ form: [String: String?]) {
        method = .post
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        body = form
            .map { key, value in "\(key)=\(encode(value ?? ""))" }
            .joined(separator: "&")
            .data(using: .utf8)
            .map { .data($0) }

        /// https://useyourloaf.com/blog/how-to-percent-encode-a-url-string/#encoding-for-x-www-form-urlencoded
        func encode(_ s: String) -> String {
            let unreserved = "*-._ "
            let allowed = NSMutableCharacterSet.alphanumeric()
            allowed.addCharacters(in: unreserved)

            return s.addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)?
                .replacingOccurrences(of: " ", with: "+")
                ?? ""
        }
    }
}

extension HTTPRequest: CustomStringConvertible {
    public var description: String {
        "\(method) \(url.absoluteString), headers: \(headers)"
    }
}

/// Convenience protocol to pass an URL or similar objects to an `HTTPClient`.
public protocol HTTPRequestConvertible {
    func httpRequest() -> HTTPResult<HTTPRequest>
}

public enum HTTPRequestError: Error {
    case invalidURL(CustomStringConvertible)
}

extension HTTPRequest: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        .success(self)
    }
}

extension Result: HTTPRequestConvertible where Success == HTTPRequest, Failure == HTTPError {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        self
    }
}

extension URL: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        .success(HTTPRequest(url: self))
    }
}

extension URLComponents: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        guard let url = url else {
            return .failure(HTTPError(kind: .malformedRequest(url: description)))
        }
        return .success(HTTPRequest(url: url))
    }
}

extension String: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        guard let url = URL(string: self) else {
            return .failure(HTTPError(kind: .malformedRequest(url: self)))
        }
        return .success(HTTPRequest(url: url))
    }
}

extension Link: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        guard let url = url(relativeTo: nil) else {
            return .failure(HTTPError(kind: .malformedRequest(url: href)))
        }
        return .success(HTTPRequest(url: url))
    }
}
