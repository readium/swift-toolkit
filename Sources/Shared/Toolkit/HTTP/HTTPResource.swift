//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// ``HTTPResource`` provides access to an external URL through HTTP.
public actor HTTPResource: Resource {
    public let url: HTTPURL

    private let client: HTTPClient

    init(url: HTTPURL, client: HTTPClient) {
        self.url = url
        self.client = client
    }

    public nonisolated var sourceURL: AbsoluteURL? {
        url
    }

    public func properties() async throws(ReadError) -> ResourceProperties {
        let response = try await headResponse()
        return ResourceProperties {
            if let response = response {
                $0.filename = response.filename ?? url.lastPathSegment
                $0.mediaType = response.mediaType
            }
        }
    }

    public func estimatedLength() async throws(ReadError) -> UInt64? {
        let response = try await headResponse()
        if let length = response?.contentLength {
            return UInt64(length)
        } else {
            return nil
        }
    }

    private var _headResponse: Result<HTTPResponse?, ReadError>?

    /// Cached HEAD response to get the expected content length and other
    /// metadata.
    private func headResponse() async throws(ReadError) -> HTTPResponse? {
        if _headResponse == nil {
            do {
                let response = try await client.fetch(HTTPRequest(url: url, method: .head))
                _headResponse = .success(response)
            } catch {
                switch error {
                case let .errorResponse(response) where response.status == .methodNotAllowed:
                    _headResponse = .success(nil)
                default:
                    _headResponse = .failure(.access(.http(error)))
                }
            }
        }
        switch _headResponse! {
        case let .success(response): return response
        case let .failure(error): throw error
        }
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async throws(ReadError) {
        let request = {
            var request = HTTPRequest(url: url)
            if let range = range {
                request.setRange(range)
            }
            return request
        }()

        do {
            _ = try await client.stream(
                request: request,
                consume: { data, _ in
                    consume(data)
                }
            )
        } catch {
            throw ReadError.access(.http(error))
        }
    }
}
