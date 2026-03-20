//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

@Suite enum DataDecodeTests {
    @Suite("decode") struct Decode {
        @Test("success") func success() throws(ReadError) {
            let data = Data([0x41, 0x42])
            let decoded: String = try data.decode { String(data: $0, encoding: .utf8)! }
            #expect(decoded == "AB")
        }

        @Test("decoding failure wraps in ReadError.decoding")
        func decodingFailure() {
            let data = Data([0xFF])
            #expect(throws: ReadError.self) {
                let _: String = try data.decode { _ in throw DebugError("bad") }
            }
        }
    }

    @Suite("asString") struct AsString {
        @Test("UTF-8 success") func utf8() throws {
            let data = try #require("hello".data(using: .utf8))
            #expect(try data.asString() == "hello")
        }

        @Test("custom encoding") func customEncoding() throws {
            let data = try #require("café".data(using: .isoLatin1))
            #expect(try data.asString(encoding: .isoLatin1) == "café")
        }

        @Test("invalid encoding produces ReadError.decoding")
        func invalidEncoding() {
            // 0x80 alone is invalid UTF-8
            let data = Data([0x80])
            #expect(throws: ReadError.self) {
                try data.asString()
            }
        }
    }

    @Suite("asJSONObject") struct AsJSONObject {
        @Test("valid JSON object") func valid() throws {
            let data = try #require(#"{"key":"value"}"#.data(using: .utf8))
            let decoded: [String: Any] = try data.asJSONObject()
            #expect(decoded["key"] as? String == "value")
        }

        @Test("invalid JSON produces ReadError.decoding")
        func invalidJSON() throws {
            let data = try #require("not json".data(using: .utf8))
            #expect(throws: ReadError.self) {
                try data.asJSONObject() as [String: Any]
            }
        }

        @Test("JSON array root produces ReadError.decoding")
        func wrongType() throws {
            let data = try #require("[1,2,3]".data(using: .utf8))
            #expect(throws: ReadError.self) {
                try data.asJSONObject() as [String: Any]
            }
        }
    }
}

@Suite enum OptionalDataDecodeTests {
    @Suite("decode") struct Decode {
        @Test("nil data passes through as nil")
        func nilPassthrough() throws(ReadError) {
            let data: Data? = nil
            let decoded: String? = try data.decode { String(data: $0, encoding: .utf8)! }
            #expect(decoded == nil)
        }

        @Test("present data is decoded") func dataPresent() throws(ReadError) {
            let data: Data? = "hello".data(using: .utf8)
            let decoded: String? = try data.decode { String(data: $0, encoding: .utf8)! }
            #expect(decoded == "hello")
        }

        @Test("decoding failure wraps in ReadError.decoding")
        func decodingFailure() {
            let data: Data? = Data([0xFF])
            #expect(throws: ReadError.self) {
                let _: String? = try data.decode { _ in throw DebugError("bad") }
            }
        }
    }

    @Suite("asString") struct AsString {
        @Test("nil passthrough") func nilPassthrough() throws(ReadError) {
            let data: Data? = nil
            #expect(try data.asString() == nil)
        }

        @Test("present data is decoded") func dataPresent() throws(ReadError) {
            let data: Data? = "world".data(using: .utf8)
            #expect(try data.asString() == "world")
        }
    }

    @Suite("asJSONObject") struct AsJSONObject {
        @Test("nil passthrough") func nilPassthrough() throws {
            let data: Data? = nil
            let decoded: [String: Any]? = try data.asJSONObject()
            #expect(decoded == nil)
        }

        @Test("present data is decoded") func dataPresent() throws {
            let data: Data? = #"{"k":1}"#.data(using: .utf8)
            let decoded: [String: Any]? = try data.asJSONObject()
            #expect(decoded?["k"] as? Int == 1)
        }
    }
}
