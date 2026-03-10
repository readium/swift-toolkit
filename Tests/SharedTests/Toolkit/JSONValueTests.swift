//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

@Suite struct JSONValueTests {
    @Suite struct Initialization {
        @Test func fromNil() {
            #expect(JSONValue(nil as Any?) == nil)
        }

        @Test func fromBool() {
            #expect(JSONValue(true) == .bool(true))
            #expect(JSONValue(false) == .bool(false))
        }

        @Test func fromString() {
            #expect(JSONValue("hello") == .string("hello"))
        }

        @Test func fromInt() {
            #expect(JSONValue(42) == .integer(42))
            #expect(JSONValue(-42) == .integer(-42))
        }

        @Test func fromUInt64() {
            #expect(JSONValue(UInt64(42)) == .integer(42))
            #expect(JSONValue(UInt64.max) == .integer(Int.max))
        }

        @Test func fromDouble() {
            #expect(JSONValue(3.14) == .double(3.14))
        }

        @Test func fromNSNull() {
            #expect(JSONValue(NSNull()) == .null)
        }

        @Test func fromNSNumber() {
            #expect(JSONValue(NSNumber(value: true)) == .bool(true))
            #expect(JSONValue(NSNumber(value: 42)) == .integer(42))
            #expect(JSONValue(NSNumber(value: -42)) == .integer(-42))
            #expect(JSONValue(NSNumber(value: 3.14)) == .double(3.14))
        }

        @Test func fromNSNumberClamping() {
            #expect(JSONValue(NSNumber(value: UInt64.max)) == .integer(Int.max))
            #expect(JSONValue(NSNumber(value: Int64.min)) == .integer(Int.min))
        }

        @Test func fromArray() {
            let array: [Any] = ["hello", 42, true]
            #expect(JSONValue(array) == .array([.string("hello"), .integer(42), .bool(true)]))
        }

        @Test func fromObject() {
            let dict: [String: Any] = ["key": "value", "count": 1]
            #expect(JSONValue(dict) == .object(["key": .string("value"), "count": .integer(1)]))
        }

        @Test func fromNestedCollections() {
            let dict: [String: Any] = [
                "nested": [
                    "array": [1, 2, 3] as [Any],
                ] as [String: Any],
            ]
            #expect(JSONValue(dict) == .object([
                "nested": .object([
                    "array": .array([.integer(1), .integer(2), .integer(3)]),
                ]),
            ]))
        }

        @Test func fastPath() {
            let original: JSONValue = .string("test")
            #expect(JSONValue(original) == original)

            let object: [String: JSONValue] = ["k": .integer(1)]
            #expect(JSONValue(object) == .object(object))

            let array: [JSONValue] = [.bool(true)]
            #expect(JSONValue(array) == .array(array))
        }
    }

    @Suite struct Accessors {
        @Test func integerAccessors() {
            let val: JSONValue = .integer(42)
            #expect(val.integer == 42)
            #expect(val.double == 42.0)
            #expect(val.string == nil)
        }

        @Test func stringAccessors() {
            let val: JSONValue = .string("test")
            #expect(val.string == "test")
            #expect(val.integer == nil)
        }
    }

    @Suite struct AnyConversion {
        @Test func null() {
            #expect(JSONValue.null.any is NSNull)
        }

        @Test func bool() {
            #expect(JSONValue.bool(true).any as? Bool == true)
        }

        @Test func string() {
            #expect(JSONValue.string("hello").any as? String == "hello")
        }

        @Test func integer() {
            #expect(JSONValue.integer(42).any as? Int == 42)
        }

        @Test func double() {
            #expect(JSONValue.double(3.14).any as? Double == 3.14)
        }

        @Test func array() {
            #expect((JSONValue.array([.integer(1)]).any as? [Int])?[0] == 1)
        }

        @Test func object() {
            #expect((JSONValue.object(["k": .integer(1)]).any as? [String: Int])?["k"] == 1)
        }
    }

    @Suite struct LiteralConformance {
        @Test func nilLiteral() {
            let val: JSONValue = nil
            #expect(val == .null)
        }

        @Test func boolLiteral() {
            let val: JSONValue = true
            #expect(val == .bool(true))
        }

        @Test func stringLiteral() {
            let val: JSONValue = "hello"
            #expect(val == .string("hello"))
        }

        @Test func integerLiteral() {
            let val: JSONValue = 42
            #expect(val == .integer(42))
        }

        @Test func floatLiteral() {
            let val: JSONValue = 3.14
            #expect(val == .double(3.14))
        }

        @Test func arrayLiteral() {
            let val: JSONValue = ["a", 1]
            #expect(val == .array([.string("a"), .integer(1)]))
        }

        @Test func dictionaryLiteral() {
            let val: JSONValue = ["k": "v"]
            #expect(val == .object(["k": .string("v")]))
        }
    }

    @Suite struct Codable {
        @Test func roundTrip() throws {
            let original: JSONValue = [
                "string": "value",
                "int": 42,
                "bool": true,
                "null": nil,
                "array": [1, 2, 3],
                "object": ["k": "v"],
            ]
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
            #expect(original == decoded)
        }

        @Test func decodesIntegerNotBool() throws {
            let data = #"{"zero": 0, "one": 1, "two": 2}"#.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
            #expect(decoded == .object([
                "zero": .integer(0),
                "one": .integer(1),
                "two": .integer(2),
            ]))
        }
    }

    @Suite struct ReadResultExtensions {
        @Suite struct NonOptionalData {
            @Test func asJSONValue() {
                let data = #"{"foo": "bar"}"#.data(using: .utf8)!
                let result: ReadResult<Data> = .success(data)
                #expect(result.asJSONValue() == .success(.object(["foo": .string("bar")])))
            }

            @Test func asJSONObjectValue() {
                let data = #"{"foo": "bar"}"#.data(using: .utf8)!
                let result: ReadResult<Data> = .success(data)
                #expect(result.asJSONObjectValue() == .success(["foo": .string("bar")]))
            }
        }

        @Suite struct OptionalData {
            @Test func asJSONValue() {
                let data = #"{"foo": "bar"}"#.data(using: .utf8)!
                let result: ReadResult<Data?> = .success(data)
                #expect(result.asJSONValue() == .success(.object(["foo": .string("bar")])))
            }

            @Test func asJSONValueWithNilData() {
                let result: ReadResult<Data?> = .success(nil)
                #expect(result.asJSONValue() == .success(nil))
            }

            @Test func asJSONObjectValue() {
                let data = #"{"foo": "bar"}"#.data(using: .utf8)!
                let result: ReadResult<Data?> = .success(data)
                #expect(result.asJSONObjectValue() == .success(["foo": .string("bar")]))
            }

            @Test func asJSONObjectValueWithNilData() {
                let result: ReadResult<Data?> = .success(nil)
                #expect(result.asJSONObjectValue() == .success(nil))
            }
        }
    }
}
