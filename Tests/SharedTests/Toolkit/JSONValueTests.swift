//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

@Suite struct JSONValueTests {
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

        @Test func dictionaryJsonObject() {
            let dict: [String: JSONValue] = ["a": .integer(1), "b": .bool(false)]
            #expect(dict.jsonObject == dict)
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

        @Test func boolAccessor() {
            #expect(JSONValue.bool(true).bool == true)
            #expect(JSONValue.bool(false).bool == false)
            #expect(JSONValue.string("true").bool == nil)
            #expect(JSONValue.integer(1).bool == nil)
        }

        @Test func doubleAccessorNonNumericReturnsNil() {
            #expect(JSONValue.string("3.14").double == nil)
            #expect(JSONValue.bool(true).double == nil)
            #expect(JSONValue.null.double == nil)
            #expect(JSONValue.array([]).double == nil)
            #expect(JSONValue.object([:]).double == nil)
        }

        @Test func arrayAccessor() {
            #expect(JSONValue.array([.integer(1), .string("a")]).array == [.integer(1), .string("a")])
            #expect(JSONValue.string("x").array == nil)
            #expect(JSONValue.null.array == nil)
        }

        @Test func objectAccessor() {
            #expect(JSONValue.object(["k": .bool(true)]).object == ["k": .bool(true)])
            #expect(JSONValue.integer(1).object == nil)
            #expect(JSONValue.null.object == nil)
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

    @Suite struct NonNegative {
        // MARK: From .integer

        @Test func integerToInt() {
            #expect(JSONValue.integer(42).nonNegative() == Int(42))
        }

        @Test func integerToUInt64() {
            #expect(JSONValue.integer(42).nonNegative() == UInt64(42))
        }

        @Test func integerToDouble() {
            #expect(JSONValue.integer(42).nonNegative() == Double(42))
        }

        @Test func integerNegativeReturnsNil() {
            #expect(JSONValue.integer(-1).nonNegative() as Int? == nil)
        }

        @Test func integerZeroIsPositive() {
            #expect(JSONValue.integer(0).nonNegative() == Int(0))
        }

        // MARK: From .double

        @Test func doubleToDouble() {
            #expect(JSONValue.double(3.14).nonNegative() == Double(3.14))
        }

        @Test func doubleToFloat() {
            #expect(JSONValue.double(3.14).nonNegative() == Float(3.14))
        }

        @Test func doubleExactToInt() {
            #expect(JSONValue.double(3.0).nonNegative() == Int(3))
        }

        @Test func doubleExactToUInt64() {
            #expect(JSONValue.double(3.0).nonNegative() == UInt64(3))
        }

        @Test func doubleNonExactToIntReturnsNil() {
            #expect(JSONValue.double(3.5).nonNegative() as Int? == nil)
        }

        @Test func doubleNegativeReturnsNil() {
            #expect(JSONValue.double(-1.5).nonNegative() as Double? == nil)
        }

        @Test func doubleZeroIsPositive() {
            #expect(JSONValue.double(0.0).nonNegative() == Double(0))
        }

        @Test func doubleAboveInt64MaxToUInt64() {
            // Values > Int64.max (~9.2e18) must not return nil for UInt64
            let value = Double(sign: .plus, exponent: 63, significand: 1) // 2^63, > Int64.max
            #expect(JSONValue.double(value).nonNegative() == UInt64(value))
        }

        // MARK: Non-numeric cases

        @Test func stringReturnsNil() {
            #expect(JSONValue.string("42").nonNegative() as Int? == nil)
        }

        @Test func boolReturnsNil() {
            #expect(JSONValue.bool(true).nonNegative() as Int? == nil)
        }

        @Test func nullReturnsNil() {
            #expect(JSONValue.null.nonNegative() as Int? == nil)
        }
    }

    @Suite struct ArrayOf {
        /// A simple JSONValueDecodable that decodes a string value.
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

        /// A simple JSONValueDecodable that decodes an object with a "name" key.
        private struct ObjectItem: JSONValueDecodable, Equatable {
            let name: String

            init(name: String) {
                self.name = name
            }

            init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
                guard let name = json?.jsonValue.object?["name"]?.string else { return nil }
                self.name = name
            }
        }

        @Test func arrayOfDecodableValues() {
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
            let json = JSONValue.array([])
            let result: [StringItem] = json.arrayOf()
            #expect(result.isEmpty)
        }

        @Test func nonArrayWithoutAllowingSingleReturnsEmpty() {
            let json = JSONValue.string("a")
            let result: [StringItem] = json.arrayOf(allowingSingle: false)
            #expect(result.isEmpty)
        }

        @Test func nonArrayWithAllowingSingleReturnsSingleElement() {
            let json = JSONValue.string("a")
            let result: [StringItem] = json.arrayOf(allowingSingle: true)
            #expect(result == [StringItem(value: "a")])
        }

        @Test func nonArrayInvalidWithAllowingSingleReturnsEmpty() {
            let json = JSONValue.integer(42)
            let result: [StringItem] = json.arrayOf(allowingSingle: true)
            #expect(result.isEmpty)
        }

        @Test func objectWithAllowingSingleReturnsSingleElement() {
            let json = JSONValue.object(["name": .string("test")])
            let result: [ObjectItem] = json.arrayOf(allowingSingle: true)
            #expect(result == [ObjectItem(name: "test")])
        }

        @Test func nullReturnsEmpty() {
            let result: [StringItem] = JSONValue.null.arrayOf()
            #expect(result.isEmpty)
        }
    }

    @Suite struct ArrayOfJSONValues {
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

        @Test func decodesAllValidElements() {
            let array: [JSONValue] = [.string("a"), .string("b"), .string("c")]
            let result: [StringItem] = array.arrayOf()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b"), StringItem(value: "c")])
        }

        @Test func skipsInvalidElements() {
            let array: [JSONValue] = [.string("a"), .integer(42), .string("b")]
            let result: [StringItem] = array.arrayOf()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b")])
        }

        @Test func emptyArrayReturnsEmpty() {
            let result: [StringItem] = [JSONValue]().arrayOf()
            #expect(result.isEmpty)
        }

        @Test func allInvalidReturnsEmpty() {
            let array: [JSONValue] = [.integer(1), .integer(2)]
            let result: [StringItem] = array.arrayOf()
            #expect(result.isEmpty)
        }
    }

    @Suite struct DictionaryInit {
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

        @Test func encodingUsesRawValue() {
            #expect(Color.red.jsonValue == .string("red"))
            #expect(Color.blue.jsonValue == .string("blue"))
        }

        @Test func decodingValidRawValue() throws {
            #expect(try Color(json: JSONValue.string("red")) == .red)
            #expect(try Color(json: JSONValue.string("green")) == .green)
        }

        @Test func decodingInvalidRawValueReturnsNil() throws {
            #expect(try Color(json: JSONValue.string("purple")) == nil)
        }

        @Test func decodingNilReturnsNil() throws {
            #expect(try Color(json: nil as JSONValue?) == nil)
        }

        @Test func decodingNonStringReturnsNil() throws {
            #expect(try Color(json: JSONValue.integer(0)) == nil)
        }

        @Test func arrayOfOnArrayFiltersInvalid() {
            let json = JSONValue.array([.string("red"), .string("purple"), .string("blue")])
            let result: [Color] = json.arrayOf()
            #expect(result == [.red, .blue])
        }

        @Test func arrayOfAllowingSingleOnSingleString() {
            let result: [Color] = JSONValue.string("green").arrayOf(allowingSingle: true)
            #expect(result == [.green])
        }

        @Test func arrayOfAllowingSingleFalseOnSingleStringReturnsEmpty() {
            let result: [Color] = JSONValue.string("red").arrayOf(allowingSingle: false)
            #expect(result.isEmpty)
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
