//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds the information about an HTTP request performed by an `HTTPClient`.
public struct HTTPRequest: Equatable, Sendable {
    /// Address of the remote resource to request.
    public var url: HTTPURL

    /// HTTP method to use for the request.
    public var method: Method

    /// Supported HTTP methods.
    public enum Method: String, Equatable, Sendable {
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
    public enum Body: Equatable, Sendable {
        case data(Data)
        case file(URL)
    }

    /// The timeout interval of the request.
    public var timeoutInterval: TimeInterval?

    /// If true, the user might be presented with interactive dialogs, such as popping up an authentication dialog.
    public var allowUserInteraction: Bool

    /// Additional context data specific to a given implementation of `HTTPClient`.
    @available(*, unavailable, message: "This was not used in the toolkit. Open a bug report issue if you used it.")
    public var userInfo: [AnyHashable: AnyHashable] {
        [:]
    }

    public init(
        url: HTTPURL,
        method: Method = .get,
        headers: [String: String] = [:],
        body: Body? = nil,
        timeoutInterval: TimeInterval? = nil,
        allowUserInteraction: Bool = false
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.allowUserInteraction = allowUserInteraction
    }

    /// User agent that will be issued with this request.
    public var userAgent: String? {
        get {
            headers["User-Agent"]
        }
        set {
            if let newValue = newValue {
                headers["User-Agent"] = newValue
            } else {
                headers.removeValue(forKey: "User-Agent")
            }
        }
    }

    /// Issue a byte range request.
    public mutating func setRange(_ range: Range<UInt64>) {
        headers["Range"] = "bytes=\(range.lowerBound)-\(range.upperBound - 1)"
    }

    /// Issue a byte range request from the given offset until the end of the resource.
    public mutating func setRange(_ range: PartialRangeFrom<UInt64>) {
        headers["Range"] = "bytes=\(range.lowerBound)-"
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
        "\(method) \(url.string), headers: \(headers)"
    }
}

/// Convenience protocol to pass an URL or similar objects to an `HTTPClient`.
public protocol HTTPRequestConvertible: Sendable {
    func httpRequest() -> HTTPResult<HTTPRequest>
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

extension HTTPURL: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        .success(HTTPRequest(url: self))
    }
}

extension URL: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        guard let url = HTTPURL(url: self) else {
            return .failure(.malformedRequest(url: absoluteString))
        }
        return url.httpRequest()
    }
}

extension URLComponents: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        guard let url = url else {
            return .failure(.malformedRequest(url: description))
        }
        return url.httpRequest()
    }
}

extension String: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        guard let url = HTTPURL(string: self) else {
            return .failure(.malformedRequest(url: self))
        }
        return url.httpRequest()
    }
}

extension Link: HTTPRequestConvertible {
    public func httpRequest() -> HTTPResult<HTTPRequest> {
        guard let url = url().httpURL else {
            return .failure(.malformedRequest(url: href))
        }
        return url.httpRequest()
    }
}
