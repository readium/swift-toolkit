//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// An HTTP client performs HTTP requests.
///
/// You may provide a custom implementation, or use the `DefaultHTTPClient` one which relies on native APIs.
public protocol HTTPClient: Loggable {
    /// Streams a resource from the given `request`.
    ///
    /// - Parameters:
    ///   - request: Request to the streamed resource.
    ///     also access it in the completion block after consuming the data.
    ///   - consume: Callback called for each chunk of data received. Callers
    ///     are responsible to accumulate the data if needed.
    func stream(
        request: HTTPRequestConvertible,
        consume: @escaping (_ chunk: Data, _ progress: Double?) -> Void
    ) async -> HTTPResult<HTTPResponse>
}

public extension HTTPClient {
    /// Fetches the resource from the given `request`.
    func fetch(_ request: HTTPRequestConvertible) async -> HTTPResult<HTTPResponse> {
        var data = Data()
        let response = await stream(
            request: request,
            consume: { chunk, _ in data.append(chunk) }
        )

        return response
            .map {
                var response = $0
                response.body = data
                return response
            }
    }

    /// Fetches the resource and attempts to decode it with the given `decoder`.
    ///
    /// If the decoder fails, a `malformedResponse` HTTP error is returned.
    func fetch<T>(
        _ request: HTTPRequestConvertible,
        decoder: @escaping (HTTPResponse, Data) throws -> T?
    ) async -> HTTPResult<T> {
        await fetch(request)
            .flatMap { response in
                do {
                    guard
                        let body = response.body,
                        let result = try decoder(response, body)
                    else {
                        return .failure(HTTPError(kind: .malformedResponse))
                    }
                    return .success(result)

                } catch {
                    return .failure(HTTPError(kind: .malformedResponse, cause: error))
                }
            }
    }

    /// Fetches the resource as a JSON object.
    func fetchJSON(_ request: HTTPRequestConvertible) async -> HTTPResult<[String: Any]> {
        await fetch(request) {
            try JSONSerialization.jsonObject(with: $1) as? [String: Any]
        }
    }

    /// Fetches the resource as a `String`.
    func fetchString(_ request: HTTPRequestConvertible) async -> HTTPResult<String> {
        await fetch(request) { response, body in
            let encoding = response.mediaType?.encoding ?? .utf8
            return String(data: body, encoding: encoding)
        }
    }

    /// Fetches the resource as an `UIImage`.
    func fetchImage(_ request: HTTPRequestConvertible) async -> HTTPResult<UIImage> {
        await fetch(request) {
            UIImage(data: $1)
        }
    }

    /// Downloads the resource at a temporary location.
    ///
    /// You are responsible for moving or deleting the downloaded file in the `completion` block.
    func download(
        _ request: HTTPRequestConvertible,
        onProgress: @escaping (Double) -> Void
    ) async -> HTTPResult<HTTPDownload> {
        let location = FileURL(
            url: URL(
                fileURLWithPath: NSTemporaryDirectory(),
                isDirectory: true
            ).appendingUniquePathSegment()
        )!

        let fileHandle: FileHandle
        do {
            try "".write(to: location.url, atomically: true, encoding: .utf8)
            fileHandle = try FileHandle(forWritingTo: location.url)
        } catch {
            return .failure(HTTPError(kind: .ioError, cause: error))
        }

        let result = await stream(
            request: request,
            consume: { data, progression in
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)

                if let progression = progression {
                    onProgress(progression)
                }
            }
        )

        do {
            try fileHandle.close()
        } catch {
            log(.warning, error)
        }

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

    @available(*, unavailable, message: "Use the async variant.")
    func stream(_ request: HTTPRequestConvertible, receiveResponse: ((HTTPResponse) -> Void)?, consume: @escaping (_ chunk: Data, _ progress: Double?) -> Void, completion: @escaping (HTTPResult<HTTPResponse>) -> Void) -> Cancellable {
        CancellableTask(task: Task {
            await completion(stream(request: request, consume: consume))
        })
    }

    @available(*, unavailable, message: "Use the async variant.")
    func stream(_ request: HTTPRequestConvertible, consume: @escaping (Data, Double?) -> Void, completion: @escaping (HTTPResult<HTTPResponse>) -> Void) -> Cancellable {
        CancellableTask(task: Task {
            await completion(stream(request: request, consume: consume))
        })
    }

    @available(*, unavailable, message: "Use the async variant.")
    func fetch(_ request: HTTPRequestConvertible, completion: @escaping (HTTPResult<HTTPResponse>) -> Void) -> Cancellable {
        CancellableTask(task: Task {
            await completion(fetch(request))
        })
    }

    @available(*, unavailable, message: "Use the async variant.")
    func fetchSync(_ request: HTTPRequestConvertible) -> HTTPResult<HTTPResponse> {
        fatalError()
    }

    @available(*, unavailable, message: "Use the async variant.")
    func fetch<T>(
        _ request: HTTPRequestConvertible,
        decoder: @escaping (HTTPResponse, Data) throws -> T?,
        completion: @escaping (HTTPResult<T>) -> Void
    ) -> Cancellable {
        fatalError()
    }

    @available(*, unavailable, message: "Use the async variant.")
    func fetchJSON(_ request: HTTPRequestConvertible, completion: @escaping (HTTPResult<[String: Any]>) -> Void) -> Cancellable {
        fatalError()
    }

    @available(*, unavailable, message: "Use the async variant.")
    func fetchString(_ request: HTTPRequestConvertible, completion: @escaping (HTTPResult<String>) -> Void) -> Cancellable {
        fatalError()
    }

    @available(*, unavailable, message: "Use the async variant.")
    func fetchImage(_ request: HTTPRequestConvertible, completion: @escaping (HTTPResult<UIImage>) -> Void) -> Cancellable {
        fatalError()
    }

    @available(*, unavailable, message: "Use the async variant.")
    func download(
        _ request: HTTPRequestConvertible,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (HTTPResult<HTTPDownload>) -> Void
    ) -> Cancellable {
        fatalError()
    }
}

/// Represents a successful HTTP response received from a server.
public struct HTTPResponse: Equatable, Sendable {
    /// Request associated with the response.
    public let request: HTTPRequest

    /// URL for the response, after any redirect.
    public let url: HTTPURL

    /// HTTP status code returned by the server.
    public let statusCode: Int

    /// HTTP response headers, indexed by their name.
    public let headers: [String: String]

    /// Media type provided in the `Content-Type` header.
    public let mediaType: MediaType?

    /// Response body content, when available.
    public var body: Data?

    public init(request: HTTPRequest, url: HTTPURL, statusCode: Int, headers: [String: String], mediaType: MediaType?, body: Data?) {
        self.request = request
        self.url = url
        self.statusCode = statusCode
        self.headers = headers
        self.mediaType = mediaType
        self.body = body
    }

    /// Finds the value of the first header matching the given name.
    ///
    /// In keeping with the HTTP RFC, HTTP header field names are case-insensitive.
    public func valueForHeader(_ name: String) -> String? {
        let name = name.lowercased()
        for (n, v) in headers {
            if n.lowercased() == name {
                return v
            }
        }
        return nil
    }

    /// Indicates whether this server supports byte range requests.
    public var acceptsByteRanges: Bool {
        valueForHeader("Accept-Ranges")?.lowercased() == "bytes"
            || valueForHeader("Content-Range")?.lowercased().hasPrefix("bytes") == true
    }

    /// The expected content length for this response, when known.
    ///
    /// Warning: For byte range requests, this will be the length of the current chunk,
    /// not the whole resource.
    public var contentLength: Int64? {
        valueForHeader("Content-Length")
            .flatMap { Int64($0) }
            .takeIf { $0 >= 0 }
    }

    /// The resource filename as provided by the server in the `Content-Disposition` header.
    public var filename: String? {
        if let disposition = headers["Content-Disposition"] {
            let array = disposition.split(separator: ";")
            var filenameString: String?
            switch array.count {
            case 1:
                filenameString = String(array[0]).trimmingCharacters(in: .whitespaces)
            case 2:
                filenameString = String(array[1]).trimmingCharacters(in: .whitespaces)
            default:
                break
            }

            if let filenameString = filenameString, filenameString.starts(with: "filename=") {
                return filenameString.replacingOccurrences(of: "filename=", with: "")
            }
        }
        return nil
    }
}

/// Holds the information about a successful download.
public struct HTTPDownload {
    /// The location of a temporary file where the server's response is stored.
    /// You are responsible for moving or deleting the downloaded file..
    public let location: FileURL

    /// A suggested filename for the response data, taken from the `Content-Disposition` header.
    public let suggestedFilename: String?

    /// Media type sniffed from the `Content-Type` header and response body.
    public let mediaType: MediaType?

    public init(location: FileURL, suggestedFilename: String? = nil, mediaType: MediaType?) {
        self.location = location
        self.suggestedFilename = suggestedFilename
        self.mediaType = mediaType
    }
}
