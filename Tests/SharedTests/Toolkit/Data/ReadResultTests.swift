//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

@Suite enum ReadResultDataTests {
    static let accessError: ReadError = .access(.fileSystem(.fileNotFound(nil)))

    @Suite("decode") struct Decode {
        @Test("success") func success() {
            let result: ReadResult<Data> = .success(Data([0x41, 0x42]))
            let decoded: ReadResult<String> = result.decode { String(data: $0, encoding: .utf8)! }
            #expect(decoded == .success("AB"))
        }

        @Test("decoding failure wraps in ReadError.decoding")
        func decodingFailure() {
            let result: ReadResult<Data> = .success(Data([0xFF]))
            let decoded: ReadResult<String> = result.decode { _ in throw DebugError("bad") }
            guard case .failure(.decoding) = decoded else {
                Issue.record("Expected ReadError.decoding, got \(decoded)")
                return
            }
        }

        @Test("read error is preserved unchanged")
        func readErrorPreserved() {
            let decoded: ReadResult<String> = accessError.asResult().decode { String(data: $0, encoding: .utf8)! }
            #expect(decoded == accessError.asResult())
        }
    }

    @Suite("asString") struct AsString {
        @Test("UTF-8 success") func utf8() throws {
            let result: ReadResult<Data> = try .success(#require("hello".data(using: .utf8)))
            #expect(result.asString() == .success("hello"))
        }

        @Test("custom encoding") func customEncoding() throws {
            let result: ReadResult<Data> = try .success(#require("café".data(using: .isoLatin1)))
            #expect(result.asString(encoding: .isoLatin1) == .success("café"))
        }

        @Test("invalid encoding produces ReadError.decoding")
        func invalidEncoding() {
            // 0x80 alone is invalid UTF-8
            let result: ReadResult<Data> = .success(Data([0x80]))
            guard case .failure(.decoding) = result.asString() else {
                Issue.record("Expected ReadError.decoding for invalid UTF-8")
                return
            }
        }
    }

    @Suite("asJSONObject") struct AsJSONObject {
        @Test("valid JSON object") func valid() throws {
            let result: ReadResult<Data> = try .success(#require(#"{"key":"value"}"#.data(using: .utf8)))
            let decoded: ReadResult<[String: Any]> = result.asJSONObject()
            #expect(try decoded.get()["key"] as? String == "value")
        }

        @Test("invalid JSON produces ReadError.decoding")
        func invalidJSON() throws {
            let result: ReadResult<Data> = try .success(#require("not json".data(using: .utf8)))
            let decoded: ReadResult<[String: Any]> = result.asJSONObject()
            guard case .failure(.decoding) = decoded else {
                Issue.record("Expected ReadError.decoding for invalid JSON")
                return
            }
        }

        @Test("JSON array root produces ReadError.decoding")
        func wrongType() throws {
            let result: ReadResult<Data> = try .success(#require("[1,2,3]".data(using: .utf8)))
            let decoded: ReadResult<[String: Any]> = result.asJSONObject()
            guard case .failure(.decoding) = decoded else {
                Issue.record("Expected ReadError.decoding when JSON root is not an object")
                return
            }
        }
    }
}

@Suite enum ReadResultOptionalDataTests {
    static let accessError: ReadError = .access(.fileSystem(.fileNotFound(nil)))

    @Suite("decode") struct Decode {
        @Test("nil data passes through as success(nil)")
        func nilPassthrough() {
            let result: ReadResult<Data?> = .success(nil)
            let decoded: ReadResult<String?> = result.decode { String(data: $0, encoding: .utf8)! }
            #expect(decoded == .success(nil))
        }

        @Test("present data is decoded") func dataPresent() {
            let result: ReadResult<Data?> = .success("hello".data(using: .utf8))
            let decoded: ReadResult<String?> = result.decode { String(data: $0, encoding: .utf8)! }
            #expect(decoded == .success("hello"))
        }

        @Test("decoding failure wraps in ReadError.decoding")
        func decodingFailure() {
            let result: ReadResult<Data?> = .success(Data([0xFF]))
            let decoded: ReadResult<String?> = result.decode { _ in throw DebugError("bad") }
            guard case .failure(.decoding) = decoded else {
                Issue.record("Expected ReadError.decoding, got \(decoded)")
                return
            }
        }

        @Test("read error is preserved unchanged")
        func readErrorPreserved() {
            let decoded: ReadResult<String?> = accessError.asResult().decode { String(data: $0, encoding: .utf8)! }
            #expect(decoded == accessError.asResult())
        }
    }

    @Suite("asString") struct AsString {
        @Test("nil passthrough") func nilPassthrough() {
            let result: ReadResult<Data?> = .success(nil)
            #expect(result.asString() == .success(nil))
        }

        @Test("present data is decoded") func dataPresent() {
            let result: ReadResult<Data?> = .success("world".data(using: .utf8))
            #expect(result.asString() == .success("world"))
        }
    }

    @Suite("asJSONObject") struct AsJSONObject {
        @Test("nil passthrough") func nilPassthrough() throws {
            let result: ReadResult<Data?> = .success(nil)
            let decoded: ReadResult<[String: Any]?> = result.asJSONObject()
            #expect(try decoded.get() == nil)
        }

        @Test("present data is decoded") func dataPresent() throws {
            let result: ReadResult<Data?> = .success(#"{"k":1}"#.data(using: .utf8))
            let decoded: ReadResult<[String: Any]?> = result.asJSONObject()
            #expect(try decoded.get()?["k"] as? Int == 1)
        }
    }
}

private extension ReadError {
    func asResult<T>() -> ReadResult<T> {
        .failure(self)
    }
}
