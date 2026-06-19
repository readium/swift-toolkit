//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct HTTPResponseTests {
    private let request = HTTPRequest(url: HTTPURL(string: "http://example.com")!)
    private let url = HTTPURL(string: "http://example.com")!

    @Test func valueForHeader() {
        let response = HTTPResponse(
            request: request,
            url: url,
            status: .ok,
            headers: ["Content-Type": "application/pdf", "X-Custom": "Value"],
            mediaType: .pdf
        )

        #expect(response.valueForHeader("Content-Type") == "application/pdf")
        #expect(response.valueForHeader("content-type") == "application/pdf")
        #expect(response.valueForHeader("X-Custom") == "Value")
        #expect(response.valueForHeader("Unknown") == nil)
    }

    @Test func acceptsByteRanges() {
        var response = HTTPResponse(request: request, url: url, status: .ok, headers: ["Accept-Ranges": "bytes"], mediaType: nil)
        #expect(response.acceptsByteRanges)

        response = HTTPResponse(request: request, url: url, status: .ok, headers: ["Content-Range": "bytes 0-100/1000"], mediaType: nil)
        #expect(response.acceptsByteRanges)

        response = HTTPResponse(request: request, url: url, status: .ok, headers: [:], mediaType: nil)
        #expect(!response.acceptsByteRanges)
    }

    @Test func contentLength() {
        let response = HTTPResponse(request: request, url: url, status: .ok, headers: ["Content-Length": "1024"], mediaType: nil)
        #expect(response.contentLength == 1024)

        let responseInvalid = HTTPResponse(request: request, url: url, status: .ok, headers: ["Content-Length": "invalid"], mediaType: nil)
        #expect(responseInvalid.contentLength == nil)
    }

    @Test func resourceLength() {
        func response(headers: [String: String]) -> HTTPResponse {
            HTTPResponse(request: request, url: url, status: .ok, headers: headers, mediaType: nil)
        }

        // No headers: unknown length.
        #expect(response(headers: [:]).resourceLength == nil)

        // Full response: Content-Length is the resource length.
        #expect(response(headers: ["Content-Length": "1000"]).resourceLength == 1000)

        // Partial response with known total: Content-Range wins over Content-Length.
        #expect(response(headers: [
            "Content-Range": "bytes 0-99/1000",
            "Content-Length": "100",
        ]).resourceLength == 1000)

        // Partial response with unknown total (bytes 0-99/*): returns nil.
        #expect(response(headers: [
            "Content-Range": "bytes 0-99/*",
            "Content-Length": "100",
        ]).resourceLength == nil)
    }

    @Test func contentByteRange() {
        func response(headers: [String: String]) -> HTTPResponse {
            HTTPResponse(request: request, url: url, status: .partialContent, headers: headers, mediaType: nil)
        }

        // No range.
        var r = response(headers: [:])
        #expect(r.contentByteRange == nil)

        // Actual range: bytes <start>-<end>/<size>
        r = response(headers: ["Content-Range": "bytes 0-100/1000"])
        #expect(r.contentByteRange == HTTPContentByteRange(range: 0 ... 100, size: 1000))
    }

    @Test func filename() {
        var response = HTTPResponse(request: request, url: url, status: .ok, headers: ["Content-Disposition": "attachment; filename=book.epub"], mediaType: nil)
        #expect(response.filename == "book.epub")

        response = HTTPResponse(request: request, url: url, status: .ok, headers: ["Content-Disposition": "filename=image.png"], mediaType: nil)
        #expect(response.filename == "image.png")

        response = HTTPResponse(request: request, url: url, status: .ok, headers: ["Content-Disposition": "inline"], mediaType: nil)
        #expect(response.filename == nil)

        response = HTTPResponse(request: request, url: url, status: .ok, headers: ["Content-Disposition": "attachment; filename*=UTF-8''%e2%82%ac%20rates; filename=fallback.txt"], mediaType: nil)
        #expect(response.filename == "€ rates")

        // Malformed UTF-8 in filename* should fall back to filename
        response = HTTPResponse(request: request, url: url, status: .ok, headers: ["Content-Disposition": "attachment; filename*=UTF-8''%FF%FF; filename=fallback.txt"], mediaType: nil)
        #expect(response.filename == "fallback.txt")
    }
}
