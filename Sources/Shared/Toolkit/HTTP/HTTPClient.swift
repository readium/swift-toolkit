//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
#if canImport(UIKit)
    import UIKit
#endif

/// An HTTP client performs HTTP requests.
///
/// You may provide a custom implementation, or use the `DefaultHTTPClient` one
/// which relies on native APIs.
public protocol HTTPClient: Loggable, Sendable {
    /// Streams a resource from the given `request`.
    ///
    /// - Parameters:
    ///   - request: Request to the streamed resource.
    ///   - onReceiveResponse: Optional callback allowing you to intercept the
    ///     response headers and cancel early with `HTTPError.cancelled`.
    ///   - consume: Callback called for each chunk of data received. Callers
    ///     are responsible to accumulate the data if needed. Return an error
    ///     to abort the request. The `progress` parameter represents the
    ///     overall resource progress (including any byte-range offset from the
    ///     `Content-Range` header for range requests), not just the progress
    ///     of the current chunk.
    ///     Important: `consume` is always called serially. Implementations must
    ///     never invoke it concurrently.
    func stream(
        _ request: HTTPRequestConvertible,
        onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)?,
        consume: @Sendable (_ chunk: Data, _ progress: Double?) -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse>
}

public extension HTTPClient {
    /// Streams a resource from the given `request`.
    ///
    /// - Parameters:
    ///   - request: Request to the streamed resource.
    ///   - consume: Callback called for each chunk of data received. Callers
    ///     are responsible to accumulate the data if needed. Return an error
    ///     to abort the request. The `progress` parameter represents the
    ///     overall resource progress (including any byte-range offset from the
    ///     `Content-Range` header for range requests), not just the progress
    ///     of the current chunk.
    ///     Important: `consume` is always called serially. Implementations must
    ///     never invoke it concurrently.
    func stream(
        _ request: HTTPRequestConvertible,
        consume: @Sendable (_ chunk: Data, _ progress: Double?) -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse> {
        await stream(request, onReceiveResponse: nil, consume: consume)
    }

    /// Fetches the resource from the given `request` and returns the
    /// accumulated data.
    func fetch(
        _ request: HTTPRequestConvertible,
        onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)? = nil
    ) async -> HTTPResult<HTTPBody> {
        let accumulator = Mutex(Data())
        let responseResult = await stream(
            request,
            onReceiveResponse: onReceiveResponse,
            consume: { chunk, _ in
                accumulator.withLock { $0.append(chunk) }
                return .success(())
            }
        )

        return responseResult.map { HTTPBody(body: accumulator.withLock { $0 }, mediaType: $0.mediaType) }
    }

    /// Fetches the resource and attempts to decode it with the given `decoder`.
    ///
    /// If the decoder fails, a `malformedResponse` HTTP error is returned.
    func fetch<T>(
        _ request: HTTPRequestConvertible,
        onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)? = nil,
        decoder: @escaping (HTTPBody) throws -> T?
    ) async -> HTTPResult<T> {
        await fetch(request, onReceiveResponse: onReceiveResponse)
            .flatMap { response in
                do {
                    guard let result = try decoder(response) else {
                        return .failure(.malformedResponse(nil))
                    }
                    return .success(result)

                } catch {
                    return .failure(.malformedResponse(error))
                }
            }
    }

    /// Fetches the resource as a JSON object.
    func fetchJSON(_ request: HTTPRequestConvertible) async -> HTTPResult<[String: Any]> {
        await fetch(request) {
            try JSONSerialization.jsonObject(with: $0.body) as? [String: Any]
        }
    }

    /// Fetches the resource as a `String`.
    func fetchString(_ request: HTTPRequestConvertible) async -> HTTPResult<String> {
        await fetch(request) {
            let encoding = $0.mediaType?.encoding ?? .utf8
            return String(data: $0.body, encoding: encoding)
        }
    }

    #if canImport(UIKit)
        /// Fetches the resource as an `UIImage`.
        func fetchImage(_ request: HTTPRequestConvertible) async -> HTTPResult<UIImage> {
            await fetch(request) {
                UIImage(data: $0.body)
            }
        }
    #endif

    /// Downloads the resource at a temporary location.
    ///
    /// You are responsible for moving or deleting the downloaded file.
    func download(
        _ request: HTTPRequestConvertible,
        onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)? = nil,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async -> HTTPResult<HTTPDownload> {
        let location = await FileURL(
            url: URL(
                fileURLWithPath: NSTemporaryDirectory(),
                isDirectory: true
            ).appendingUniquePathSegment()
        )!

        let fileHandle: FileHandle
        do {
            try Data().write(to: location.url)
            fileHandle = try FileHandle(forWritingTo: location.url)
        } catch {
            return .failure(.fileSystem(.io(error)))
        }
        defer { try? fileHandle.close() }

        let result = await stream(
            request,
            onReceiveResponse: onReceiveResponse,
            consume: { data, progression in
                do {
                    try fileHandle.write(contentsOf: data)
                } catch {
                    return .failure(.fileSystem(.io(error)))
                }

                if let progression = progression {
                    onProgress(progression)
                }

                return .success(())
            }
        )

        switch result {
        case let .success(response):
            return .success(HTTPDownload(
                location: location,
                suggestedFilename: response.filename,
                mediaType: response.mediaType
            ))

        case let .failure(error):
            do {
                try FileManager.default.removeItem(at: location.url)
            } catch {
                log(.warning, error)
            }
            return .failure(error)
        }
    }
}

/// Status code of an HTTP response.
public struct HTTPStatus: Equatable, Sendable, RawRepresentable, ExpressibleByIntegerLiteral {
    public let rawValue: Int

    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: IntegerLiteralType) {
        rawValue = value
    }

    /// Returns whether this represents a successful HTTP status.
    public var isSuccess: Bool {
        (200 ..< 300).contains(rawValue)
    }

    /// (200) OK.
    public static let ok = HTTPStatus(rawValue: 200)

    /// (206) This response code is used in response to a range request when the
    /// client has requested a part or parts of a resource.
    public static let partialContent = HTTPStatus(rawValue: 206)

    /// (400) The server cannot or will not process the request due to an
    /// apparent client error.
    public static let badRequest = HTTPStatus(rawValue: 400)

    /// (401) Authentication is required and has failed or has not yet been
    /// provided.
    public static let unauthorized = HTTPStatus(rawValue: 401)

    /// (403) The server refuses the action, probably because we don't have the
    /// necessary permissions.
    public static let forbidden = HTTPStatus(rawValue: 403)

    /// (404) The requested resource could not be found.
    public static let notFound = HTTPStatus(rawValue: 404)

    /// (405) Method not allowed.
    public static let methodNotAllowed = HTTPStatus(rawValue: 405)

    /// (500) Internal server error.
    public static let internalServerError = HTTPStatus(rawValue: 500)
}

/// Represents a successful HTTP response received from a server.
public struct HTTPResponse: Equatable, Sendable, HTTPHeadersProviding {
    /// Request associated with the response.
    public let request: HTTPRequest

    /// URL for the response, after any redirect.
    public let url: HTTPURL

    /// HTTP status code returned by the server.
    public let status: HTTPStatus

    /// HTTP response headers, indexed by their name.
    public let headers: [String: String]

    /// Media type provided in the `Content-Type` header.
    public let mediaType: MediaType?

    public init(
        request: HTTPRequest,
        url: HTTPURL,
        status: HTTPStatus,
        headers: [String: String],
        mediaType: MediaType?
    ) {
        self.request = request
        self.url = url
        self.status = status
        self.headers = headers
        self.mediaType = mediaType
    }
}

/// Holds the information about a successful fetch.
public struct HTTPBody: Equatable, Sendable {
    /// The raw data received in the response body.
    public let body: Data

    /// Media type provided in the `Content-Type` header.
    public let mediaType: MediaType?

    public init(body: Data, mediaType: MediaType?) {
        self.body = body
        self.mediaType = mediaType
    }
}

/// Holds the information about a successful download.
public struct HTTPDownload: Equatable, Sendable {
    /// The location of a temporary file where the server's response is stored.
    /// You are responsible for moving or deleting the downloaded file.
    public let location: FileURL

    /// A suggested filename for the response data, taken from the
    /// `Content-Disposition` header.
    public let suggestedFilename: String?

    /// Media type provided in the `Content-Type` header.
    public let mediaType: MediaType?

    public init(location: FileURL, suggestedFilename: String? = nil, mediaType: MediaType?) {
        self.location = location
        self.suggestedFilename = suggestedFilename
        self.mediaType = mediaType
    }
}

/// A protocol that provides access to HTTP headers.
///
/// Conforming types must provide a dictionary of HTTP headers. The protocol
/// extension provides convenient typed accessors for common HTTP headers.
public protocol HTTPHeadersProviding {
    /// HTTP response headers, indexed by their name.
    var headers: [String: String] { get }
}

public extension HTTPHeadersProviding {
    /// Finds the value of the first header matching the given name.
    ///
    /// In keeping with the HTTP RFC, HTTP header field names are case-insensitive.
    func valueForHeader(_ name: String) -> String? {
        let name = name.lowercased()
        for (n, v) in headers {
            if n.lowercased() == name {
                return v
            }
        }
        return nil
    }

    /// The expected content length for this response, when known.
    ///
    /// - Warning: For byte range requests, this will be the length of the
    /// current chunk, not the whole resource. Use `resourceLength`
    /// instead.
    var contentLength: Int64? {
        valueForHeader("Content-Length")
            .flatMap { Int64($0) }
            .takeIf { $0 >= 0 }
    }

    /// The length of the full resource, when known.
    ///
    /// For byte range requests this reads the size from the `Content-Range`
    /// header (e.g. `bytes 0-99/1000` → 1000). Falls back to `Content-Length`
    /// only when no `Content-Range` header is present (i.e. a full response).
    /// Returns `nil` when the total size cannot be determined.
    var resourceLength: Int64? {
        if let byteRange = contentByteRange {
            return byteRange.size
        }
        return contentLength
    }

    /// Indicates whether this server supports byte range requests.
    var acceptsByteRanges: Bool {
        valueForHeader("Accept-Ranges")?.lowercased() == "bytes"
            || valueForHeader("Content-Range")?.lowercased().hasPrefix("bytes") == true
    }

    /// Parsed `Content-Range` header for this response, or `nil` if the header
    /// is absent or malformed.
    var contentByteRange: HTTPContentByteRange? {
        valueForHeader("Content-Range")
            .flatMap { HTTPContentByteRange(header: $0) }
    }

    /// The resource filename as provided by the server in the `Content-Disposition` header.
    var filename: String? {
        guard let disposition = valueForHeader("Content-Disposition") else {
            return nil
        }

        let parts = disposition.split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Look for filename* first as it takes precedence
        for part in parts {
            if part.hasPrefix("filename*=") {
                let value = part.replacingOccurrences(of: "filename*=", with: "")
                let encodingParts = value.split(separator: "'", omittingEmptySubsequences: false)
                if encodingParts.count == 3 {
                    let encoding = String(encodingParts[0]).lowercased()
                    let encodedFilename = String(encodingParts[2])
                    if encoding == "utf-8", let decoded = encodedFilename.removingPercentEncoding {
                        return decoded
                    }
                }
            }
        }

        // Fallback to filename
        for part in parts {
            if part.hasPrefix("filename=") {
                var value = part.replacingOccurrences(of: "filename=", with: "")
                if value.hasPrefix("\""), value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                return value
            }
        }

        return nil
    }
}
