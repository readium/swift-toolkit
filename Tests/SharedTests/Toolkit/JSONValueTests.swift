//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

@Suite struct JSONValueTests {
    /// Shared helper used by ArrayOf and ArrayOfJSONValues suites.
    private struct StringItem: JSONValueDecodable, Equatable {
        let value: String

        init(value: String) {
            self.value = value
        }

        init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
            guard let string = json?.jsonValue.string else { return nil }
            value = string
        }
    }

    @Suite struct JSONValueEncodableConformances {
        @Test func string() {
            #expect("hello".jsonValue == .string("hello"))
        }

        @Test func bool() {
            #expect(true.jsonValue == .bool(true))
            #expect(false.jsonValue == .bool(false))
        }

        @Test func int() {
            #expect(42.jsonValue == .integer(42))
            #expect((-42).jsonValue == .integer(-42))
        }

        @Test func double() {
            #expect(3.14.jsonValue == .double(3.14))
        }

        @Test func uint64Clamping() {
            #expect(UInt64(42).jsonValue == .integer(42))
            #expect(UInt64.max.jsonValue == .integer(Int.max))
        }

        @Test func nsNull() {
            #expect(NSNull().jsonValue == .null)
        }

        @Test func nsNumber() {
            #expect(NSNumber(value: true).jsonValue == .bool(true))
            #expect(NSNumber(value: 42).jsonValue == .integer(42))
            #expect(NSNumber(value: -42).jsonValue == .integer(-42))
            #expect(NSNumber(value: 3.14).jsonValue == .double(3.14))
        }

        @Test func nsNumberClamping() {
            #expect(NSNumber(value: UInt64.max).jsonValue == .integer(Int.max))
            #expect(NSNumber(value: Int64.min).jsonValue == .integer(Int.min))
        }

        @Test func optional() {
            #expect(String?.none.jsonValue == .null)
            #expect(String?.some("hello").jsonValue == .string("hello"))
        }

        @Test func array() {
            let array: [JSONValue] = ["hello", 42, true]
            #expect(array.jsonValue == .array([.string("hello"), .integer(42), .bool(true)]))
        }

        @Test func object() {
            let dict: [String: JSONValue] = ["key": .string("value"), "count": .integer(1)]
            #expect(dict.jsonValue == .object(["key": .string("value"), "count": .integer(1)]))
        }

        @Test func jsonValueIsIdentity() {
            let value: JSONValue = .string("test")
            #expect(value.jsonValue == value)
        }
    }

    @Suite struct JSONValueDecodableConformances {
        @Test func string() throws {
            #expect(try String(json: JSONValue.string("hello")) == "hello")
            #expect(try String(json: JSONValue.integer(42)) == nil)
        }

        @Test func bool() throws {
            #expect(try Bool(json: JSONValue.bool(true)) == true)
            #expect(try Bool(json: JSONValue.bool(false)) == false)
            #expect(try Bool(json: JSONValue.string("true")) == nil)
        }

        @Test func int() throws {
            #expect(try Int(json: JSONValue.integer(42)) == 42)
            #expect(try Int(json: JSONValue.double(3.14)) == nil)
        }

        @Test func double() throws {
            #expect(try Double(json: JSONValue.double(3.14)) == 3.14)
            #expect(try Double(json: JSONValue.integer(42)) == 42.0)
            #expect(try Double(json: JSONValue.string("3.14")) == nil)
        }

        @Test func nilJson() throws {
            #expect(try String(json: nil as JSONValue?) == nil)
            #expect(try Int(json: nil as JSONValue?) == nil)
        }
    }

    /// All tests are per-accessor: each verifies the happy path and
    /// representative nil cases for one accessor property.
    @Suite struct Accessors {
        @Test func bool() {
            #expect(JSONValue.bool(true).bool == true)
            #expect(JSONValue.bool(false).bool == false)
            #expect(JSONValue.string("true").bool == nil)
            #expect(JSONValue.integer(1).bool == nil)
        }

        @Test func string() {
            #expect(JSONValue.string("test").string == "test")
            #expect(JSONValue.integer(42).string == nil)
            #expect(JSONValue.null.string == nil)
        }

        @Test func integer() {
            #expect(JSONValue.integer(42).integer == 42)
            #expect(JSONValue.double(3.14).integer == nil)
            #expect(JSONValue.string("42").integer == nil)
        }

        @Test func double() {
            #expect(JSONValue.double(3.14).double == 3.14)
            #expect(JSONValue.integer(42).double == 42.0) // integer promotes to double
            #expect(JSONValue.string("3.14").double == nil)
            #expect(JSONValue.bool(true).double == nil)
            #expect(JSONValue.null.double == nil)
            #expect(JSONValue.array([]).double == nil)
            #expect(JSONValue.object([:]).double == nil)
        }

        @Test func array() {
            #expect(JSONValue.array([.integer(1), .string("a")]).array == [.integer(1), .string("a")])
            #expect(JSONValue.string("x").array == nil)
            #expect(JSONValue.null.array == nil)
        }

        @Test func object() {
            #expect(JSONValue.object(["k": .bool(true)]).object == ["k": .bool(true)])
            #expect(JSONValue.integer(1).object == nil)
            #expect(JSONValue.null.object == nil)
        }
    }

    @Suite struct AnyConversion {
        @Test func primitives() {
            #expect(JSONValue.null.any is NSNull)
            #expect(JSONValue.bool(true).any as? Bool == true)
            #expect(JSONValue.string("hello").any as? String == "hello")
            #expect(JSONValue.integer(42).any as? Int == 42)
            #expect(JSONValue.double(3.14).any as? Double == 3.14)
        }

        @Test func collections() {
            #expect((JSONValue.array([.integer(1)]).any as? [Any])?.first as? Int == 1)
            #expect((JSONValue.object(["k": .integer(1)]).any as? [String: Any])?["k"] as? Int == 1)
        }
    }

    @Suite struct LiteralConformance {
        @Test func scalarLiterals() {
            #expect(nil as JSONValue == .null)
            #expect(true as JSONValue == .bool(true))
            #expect("hello" as JSONValue == .string("hello"))
            #expect(42 as JSONValue == .integer(42))
            #expect(3.14 as JSONValue == .double(3.14))
        }

        @Test func collectionLiterals() {
            #expect(["a", 1] as JSONValue == .array([.string("a"), .integer(1)]))
            #expect(["k": "v"] as JSONValue == .object(["k": .string("v")]))
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

    @Suite struct NonNegative {
        @Test func fromInteger() {
            #expect(JSONValue.integer(42).nonNegative() == Int(42))
            #expect(JSONValue.integer(42).nonNegative() == UInt64(42))
            #expect(JSONValue.integer(42).nonNegative() == Double(42))
            #expect(JSONValue.integer(0).nonNegative() == Int(0)) // zero is non-negative
            #expect(JSONValue.integer(-1).nonNegative() as Int? == nil)
        }

        @Test func fromDouble() {
            #expect(JSONValue.double(3.14).nonNegative() == Double(3.14))
            #expect(JSONValue.double(3.14).nonNegative() == Float(3.14))
            #expect(JSONValue.double(3.0).nonNegative() == Int(3))
            #expect(JSONValue.double(3.0).nonNegative() == UInt64(3))
            #expect(JSONValue.double(3.5).nonNegative() as Int? == nil) // fractional rejected
            #expect(JSONValue.double(0.0).nonNegative() == Double(0))
            #expect(JSONValue.double(-1.5).nonNegative() as Double? == nil)
        }

        @Test func doubleAboveInt64MaxToUInt64() {
            // Values > Int64.max (~9.2e18) must not return nil for UInt64
            let value = Double(sign: .plus, exponent: 63, significand: 1) // 2^63
            #expect(JSONValue.double(value).nonNegative() == UInt64(value))
        }

        @Test func nonNumericReturnsNil() {
            #expect(JSONValue.string("42").nonNegative() as Int? == nil)
            #expect(JSONValue.bool(true).nonNegative() as Int? == nil)
            #expect(JSONValue.null.nonNegative() as Int? == nil)
        }
    }

    @Suite struct ArrayOf {
        @Test func decodesArray() {
            let json = JSONValue.array([.string("a"), .string("b"), .string("c")])
            let result: [StringItem] = json.arrayOf()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b"), StringItem(value: "c")])
        }

        @Test func skipsInvalidValues() {
            let json = JSONValue.array([.string("a"), .integer(42), .string("b")])
            let result: [StringItem] = json.arrayOf()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b")])
        }

        @Test func emptyArrayReturnsEmpty() {
            let result: [StringItem] = JSONValue.array([]).arrayOf()
            #expect(result.isEmpty)
        }

        @Test func nullReturnsEmpty() {
            let result: [StringItem] = JSONValue.null.arrayOf()
            #expect(result.isEmpty)
        }

        @Test func allowingSingleOnNonArray() {
            #expect(
                (JSONValue.string("a").arrayOf(allowingSingle: true) as [StringItem])
                    == [StringItem(value: "a")]
            )
            #expect(
                (JSONValue.string("a").arrayOf(allowingSingle: false) as [StringItem]).isEmpty
            )
            #expect(
                (JSONValue.integer(42).arrayOf(allowingSingle: true) as [StringItem]).isEmpty
            )
        }
    }

    @Suite struct ArrayOfJSONValues {
        @Test func decodesValidElements() {
            let array: [JSONValue] = [.string("a"), .string("b"), .string("c")]
            let result: [StringItem] = array.arrayOf()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b"), StringItem(value: "c")])
        }

        @Test func skipsInvalidElements() {
            let array: [JSONValue] = [.string("a"), .integer(42), .string("b")]
            let result: [StringItem] = array.arrayOf()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b")])
        }

        @Test func emptyOrAllInvalidReturnsEmpty() {
            #expect(([JSONValue]().arrayOf() as [StringItem]).isEmpty)
            #expect(([JSONValue.integer(1), .integer(2)].arrayOf() as [StringItem]).isEmpty)
        }
    }

    @Suite struct DictionaryInit {
        @Test func jsonObjectIsIdentity() {
            let dict: [String: JSONValue] = ["a": .integer(1), "b": .bool(false)]
            #expect(dict.jsonObject == dict)
        }

        @Test func filteringNullByDefaultRemovesNullValues() {
            let result = [String: JSONValue](["a": "hello", "b": String?.none])
            #expect(result == ["a": .string("hello")])
        }

        @Test func filteringNullFalseKeepsNullValues() {
            let result = [String: JSONValue](["a": "hello", "b": String?.none], filteringNull: false)
            #expect(result == ["a": .string("hello"), "b": .null])
        }

        @Test func addingMergesExtraKeys() {
            let result = [String: JSONValue](["a": "x"], adding: ["b": "y"])
            #expect(result == ["a": .string("x"), "b": .string("y")])
        }

        @Test func dictWinsOverAddingOnCollision() {
            let result = [String: JSONValue](["a": "dict"], adding: ["a": "additional"])
            #expect(result["a"] == .string("dict"))
        }

        @Test func emptyDictWithAdding() {
            let result = [String: JSONValue]([:], adding: ["b": 42])
            #expect(result == ["b": .integer(42)])
        }
    }

    @Suite struct Pop {
        @Test func presentKeyReturnsValueAndRemovesIt() {
            var dict: [String: JSONValue] = ["a": .integer(1), "b": .string("x")]
            let value = dict.pop("a")
            #expect(value == .integer(1))
            #expect(dict == ["b": .string("x")])
        }

        @Test func absentKeyReturnsNilAndLeavesDict() {
            var dict: [String: JSONValue] = ["a": .integer(1)]
            let value = dict.pop("z")
            #expect(value == nil)
            #expect(dict == ["a": .integer(1)])
        }
    }

    @Suite struct OrNullIfEmpty {
        @Test func emptyArrayReturnsNull() {
            #expect(([] as [String]).orNullIfEmpty == .null)
        }

        @Test func nonEmptyArrayReturnsArray() {
            #expect(["a", "b"].orNullIfEmpty == .array([.string("a"), .string("b")]))
        }

        @Test func emptyDictReturnsNull() {
            #expect([String: JSONValue]().orNullIfEmpty == .null)
        }

        @Test func nonEmptyDictReturnsObject() {
            let dict: [String: JSONValue] = ["x": .integer(7)]
            #expect(dict.orNullIfEmpty == .object(["x": .integer(7)]))
        }
    }

    @Suite struct RawRepresentableConformances {
        private enum Color: String, JSONValueEncodable, JSONValueDecodable {
            case red, green, blue
        }

        @Test func encoding() {
            #expect(Color.red.jsonValue == .string("red"))
            #expect(Color.blue.jsonValue == .string("blue"))
        }

        @Test func decoding() throws {
            #expect(try Color(json: JSONValue.string("red")) == .red)
            #expect(try Color(json: JSONValue.string("purple")) == nil) // invalid raw value
            #expect(try Color(json: nil as JSONValue?) == nil)
            #expect(try Color(json: JSONValue.integer(0)) == nil) // wrong type
        }

        @Test func arrayOf() {
            let json = JSONValue.array([.string("red"), .string("purple"), .string("blue")])
            #expect((json.arrayOf() as [Color]) == [.red, .blue]) // "purple" filtered
        }

        @Test func arrayOfAllowingSingle() {
            #expect(
                (JSONValue.string("green").arrayOf(allowingSingle: true) as [Color]) == [.green]
            )
            #expect(
                (JSONValue.string("red").arrayOf(allowingSingle: false) as [Color]).isEmpty
            )
        }
    }

    @Suite struct DateParsing {
        @Test func validISO8601StringReturnsDate() {
            let date = JSONValue.string("2019-03-12T07:58:31Z").date
            #expect(date != nil)
            #expect(date?.timeIntervalSince1970 == 1_552_377_511)
        }

        @Test func invalidStringReturnsNil() {
            #expect(JSONValue.string("not-a-date").date == nil)
            #expect(JSONValue.string("").date == nil)
        }

        @Test func nonStringReturnsNil() {
            #expect(JSONValue.integer(42).date == nil)
            #expect(JSONValue.bool(true).date == nil)
            #expect(JSONValue.null.date == nil)
        }
    }

    @Suite struct ReadResultExtensions {
        @Suite struct NonOptionalData {
            @Test func asJSONValue() {
                let data = #"{"foo": "bar"}"#.data(using: .utf8)!
                let result: ReadResult<Data> = .success(data)
                #expect(result.asJSONValue() == .success(.object(["foo": .string("bar")])))
            }

            @Test func asJSONValueFailsOnInvalidData() {
                let data = "not valid json".data(using: .utf8)!
                #expect(throws: (any Error).self) {
                    try ReadResult<Data>.success(data).asJSONValue().get()
                }
            }

            @Test func asJSONObjectValue() {
                let data = #"{"foo": "bar"}"#.data(using: .utf8)!
                let result: ReadResult<Data> = .success(data)
                #expect(result.asJSONObjectValue() == .success(["foo": .string("bar")]))
            }

            @Test func asJSONObjectValueFailsOnNonObject() {
                let data = "[1, 2, 3]".data(using: .utf8)!
                #expect(throws: (any Error).self) {
                    try ReadResult<Data>.success(data).asJSONObjectValue().get()
                }
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
