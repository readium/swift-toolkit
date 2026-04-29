//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum JSONValueTests {
    /// Shared helper used by Decode suites.
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

    struct JSONValueEncodableConformances {
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

    struct JSONValueDecodableConformances {
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
    struct Accessors {
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

    struct FromAny {
        /// nil input → failable init returns nil (not .null)
        @Test func nilReturnsNil() {
            #expect(JSONValue(nil) == nil)
        }

        /// NSNull → .null
        @Test func nsNull() {
            #expect(JSONValue(NSNull()) == .null)
        }

        /// NSNumber booleans (from JSONSerialization) → .bool
        @Test func nsNumberBool() {
            #expect(JSONValue(NSNumber(value: true)) == .bool(true))
            #expect(JSONValue(NSNumber(value: false)) == .bool(false))
        }

        /// NSNumber integers → .integer (with clamping for out-of-range values)
        @Test func nsNumberInt() {
            #expect(JSONValue(NSNumber(value: 42)) == .integer(42))
            #expect(JSONValue(NSNumber(value: -1)) == .integer(-1))
            #expect(JSONValue(NSNumber(value: UInt64.max)) == .integer(Int.max))
            #expect(JSONValue(NSNumber(value: Int64.min)) == .integer(Int.min))
        }

        /// NSNumber floats → .double
        @Test func nsNumberDouble() {
            #expect(JSONValue(NSNumber(value: 3.14)) == .double(3.14))
        }

        /// Native Swift types (bridge through NSNumber)
        @Test func swiftBool() {
            let t = true
            #expect(JSONValue(t as Any) == .bool(true))
            #expect(JSONValue(false as Any) == .bool(false))
        }

        @Test func swiftInt() {
            #expect(JSONValue(42 as Int as Any) == .integer(42))
            #expect(JSONValue(-7 as Int as Any) == .integer(-7))
        }

        @Test func swiftDouble() {
            #expect(JSONValue(2.5 as Double as Any) == .double(2.5))
        }

        /// String
        @Test func string() {
            #expect(JSONValue("hello" as Any) == .string("hello"))
        }

        /// Arrays — valid and mixed-validity elements
        @Test func array() {
            let raw: [Any] = [NSNumber(value: 1), "two", NSNumber(value: true)]
            #expect(JSONValue(raw as Any) == .array([.integer(1), .string("two"), .bool(true)]))
        }

        @Test func arrayFiltersUnknownElements() throws {
            // Elements that can't be converted (e.g., a raw struct) are dropped via compactMap
            let raw: [Any] = try ["keep", #require(URL(string: "https://example.com")) as Any, NSNumber(value: 99)]
            #expect(JSONValue(raw as Any) == .array([.string("keep"), .integer(99)]))
        }

        /// Objects
        @Test func object() {
            let raw: [String: Any] = ["a": NSNumber(value: 1), "b": "hello"]
            #expect(JSONValue(raw as Any) == .object(["a": .integer(1), "b": .string("hello")]))
        }

        @Test func objectFiltersUnknownValues() throws {
            let raw: [String: Any] = try ["keep": "yes", "drop": #require(URL(string: "https://example.com")) as Any]
            #expect(JSONValue(raw as Any) == .object(["keep": .string("yes")]))
        }

        /// Nested structures
        @Test func nested() {
            let raw: [String: Any] = ["nums": [NSNumber(value: 1), NSNumber(value: 2)]]
            #expect(JSONValue(raw as Any) == .object(["nums": .array([.integer(1), .integer(2)])]))
        }

        /// Unknown type → nil
        @Test func unknownTypeReturnsNil() {
            struct Opaque {}
            #expect(JSONValue(Opaque() as Any) == nil)
        }
    }

    struct AnyConversion {
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

    struct LiteralConformance {
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

    struct NonNegative {
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

    struct DecodeSingle {
        @Test func decodesValidValue() throws {
            let result: StringItem? = try JSONValue.string("hello").decode()
            #expect(result == StringItem(value: "hello"))
        }

        @Test func returnsNilForWrongType() throws {
            let result: StringItem? = try JSONValue.integer(42).decode()
            #expect(result == nil)
        }

        @Test func returnsNilForNull() throws {
            let result: StringItem? = try JSONValue.null.decode()
            #expect(result == nil)
        }

        @Test func forwardsWarnings() throws {
            struct Warned: JSONValueDecodable {
                init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
                    guard json?.jsonValue.string != nil else {
                        warnings?.log("Not a string", model: Warned.self)
                        return nil
                    }
                }
            }
            let logger = ListWarningLogger()
            let result: Warned? = try JSONValue.integer(1).decode(warnings: logger)
            #expect(result == nil)
            #expect(logger.warnings.count == 1)
        }
    }

    struct DecodeArray {
        @Test func decodesArray() {
            let json = JSONValue.array([.string("a"), .string("b"), .string("c")])
            let result: [StringItem] = json.decode()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b"), StringItem(value: "c")])
        }

        @Test func skipsInvalidValues() {
            let json = JSONValue.array([.string("a"), .integer(42), .string("b")])
            let result: [StringItem] = json.decode()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b")])
        }

        @Test func emptyArrayReturnsEmpty() {
            let result: [StringItem] = JSONValue.array([]).decode()
            #expect(result.isEmpty)
        }

        @Test func nullReturnsEmpty() {
            let result: [StringItem] = JSONValue.null.decode()
            #expect(result.isEmpty)
        }

        @Test func allowingSingleOnNonArray() {
            #expect(
                (JSONValue.string("a").decode(allowingSingle: true) as [StringItem])
                    == [StringItem(value: "a")]
            )
            #expect(
                (JSONValue.string("a").decode(allowingSingle: false) as [StringItem]).isEmpty
            )
            #expect(
                (JSONValue.integer(42).decode(allowingSingle: true) as [StringItem]).isEmpty
            )
        }
    }

    struct Decode {
        @Test func decodesValidElements() {
            let array: [JSONValue] = [.string("a"), .string("b"), .string("c")]
            let result: [StringItem] = array.decode()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b"), StringItem(value: "c")])
        }

        @Test func skipsInvalidElements() {
            let array: [JSONValue] = [.string("a"), .integer(42), .string("b")]
            let result: [StringItem] = array.decode()
            #expect(result == [StringItem(value: "a"), StringItem(value: "b")])
        }

        @Test func emptyOrAllInvalidReturnsEmpty() {
            #expect(([JSONValue]().decode() as [StringItem]).isEmpty)
            #expect(([JSONValue.integer(1), .integer(2)].decode() as [StringItem]).isEmpty)
        }
    }

    struct DictionaryInit {
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

    struct Pop {
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

    struct OrNullIfEmpty {
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

    struct RawRepresentableConformances {
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

        @Test func decode() {
            let json = JSONValue.array([.string("red"), .string("purple"), .string("blue")])
            #expect((json.decode() as [Color]) == [.red, .blue]) // "purple" filtered
        }

        @Test func decodeAllowingSingle() {
            #expect(
                (JSONValue.string("green").decode(allowingSingle: true) as [Color]) == [.green]
            )
            #expect(
                (JSONValue.string("red").decode(allowingSingle: false) as [Color]).isEmpty
            )
        }
    }

    struct DateParsing {
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

    struct Serialization {
        private let value: JSONValue = [
            "string": "hello",
            "int": 42,
            "bool": true,
            "null": nil,
            "array": [1, 2],
            "nested": ["k": "v"],
        ]

        @Test func jsonDataRoundTrips() throws {
            let data = try value.jsonData()
            #expect(try JSONValue(jsonData: data) == value)
        }

        @Test func jsonStringRoundTrips() throws {
            let string = try value.jsonString()
            #expect(try JSONValue(jsonString: string) == value)
        }

        @Test func jsonStringAndDataAreConsistent() throws {
            let string = try value.jsonString()
            let data = try value.jsonData()
            #expect(string == String(data: data, encoding: .utf8))
        }

        @Test func serializingViaJSONValueEncodable() throws {
            let string = try "hello".jsonString()
            #expect(try JSONValue(jsonString: string) == .string("hello"))
        }

        @Test func scalarRootsSerialize() throws {
            #expect(try JSONValue.string("hi").jsonString() == #""hi""#)
            #expect(try JSONValue.integer(42).jsonString() == "42")
            #expect(try JSONValue.double(3.5).jsonString() == "3.5")
            #expect(try JSONValue.bool(true).jsonString() == "true")
            #expect(try JSONValue.null.jsonString() == "null")
        }

        @Test func keysAreSorted() throws {
            let json: JSONValue = ["z": 1, "a": 2, "m": 3]
            #expect(try json.jsonString() == #"{"a":2,"m":3,"z":1}"#)
        }

        @Test func slashesAreNotEscaped() throws {
            #expect(try JSONValue.string("http://example.com/path").jsonString() == #""http://example.com/path""#)
        }
    }

    struct Deserialization {
        @Test func initFromValidJSONData() throws {
            let data = #"{"key": "value", "count": 3}"#.data(using: .utf8)!
            let value = try JSONValue(jsonData: data)
            #expect(value == .object(["key": .string("value"), "count": .integer(3)]))
        }

        @Test func initFromValidJSONString() throws {
            let value = try JSONValue(jsonString: #"{"key": "value", "count": 3}"#)
            #expect(value == .object(["key": .string("value"), "count": .integer(3)]))
        }

        @Test func initFromJSONArray() throws {
            let value = try JSONValue(jsonString: "[1, true, \"x\"]")
            #expect(value == .array([.integer(1), .bool(true), .string("x")]))
        }

        @Test func initFromJSONNull() throws {
            #expect(try JSONValue(jsonString: "null") == .null)
        }

        @Test func initFromJSONDataThrowsOnInvalidData() {
            let invalid = "not json".data(using: .utf8)!
            #expect(throws: JSONError.self) {
                try JSONValue(jsonData: invalid)
            }
        }

        @Test func initFromJSONStringThrowsOnInvalidString() {
            #expect(throws: JSONError.self) {
                try JSONValue(jsonString: "not json")
            }
        }

        @Test func scalarRootsDeserialize() throws {
            #expect(try JSONValue(jsonString: #""hello""#) == .string("hello"))
            #expect(try JSONValue(jsonString: "42") == .integer(42))
            #expect(try JSONValue(jsonString: "3.14") == .double(3.14))
            #expect(try JSONValue(jsonString: "true") == .bool(true))
        }

        @Test func integerNotDecodedAsBool() throws {
            // Regression: 0/1 must decode as .integer, not .bool
            let value = try JSONValue(jsonString: #"{"zero": 0, "one": 1}"#)
            #expect(value == .object(["zero": .integer(0), "one": .integer(1)]))
        }

        @Test func boolNotDecodedAsInteger() throws {
            // Complement: true/false must decode as .bool, not .integer
            let value = try JSONValue(jsonString: #"{"t": true, "f": false}"#)
            #expect(value == .object(["t": .bool(true), "f": .bool(false)]))
        }

        @Test func doublePreserved() throws {
            let value = try JSONValue(jsonString: #"{"pi": 3.14, "half": 2.5}"#)
            #expect(value == .object(["pi": .double(3.14), "half": .double(2.5)]))
        }

        @Test func roundTripsWithSerialization() throws {
            let original: JSONValue = ["title": "Moby Dick", "year": 1851, "inPrint": true]
            #expect(try JSONValue(jsonString: original.jsonString()) == original)
        }

        @Test func warningsAreForwardedFromJSONData() throws {
            struct Tag: JSONObjectEncodable, JSONValueDecodable, Equatable {
                let name: String
                init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
                    guard let name = json?.jsonValue.object?["name"]?.string else {
                        warnings?.log("Missing 'name'", model: Tag.self)
                        return nil
                    }
                    self.name = name
                }

                var jsonObject: [String: JSONValue] {
                    ["name": .string(name)]
                }
            }

            let logger = ListWarningLogger()
            #expect(throws: JSONError.self) {
                try Tag(jsonData: #require(#"{"other": "field"}"#.data(using: .utf8)), warnings: logger)
            }
            #expect(logger.warnings.count == 1)
        }

        @Test func warningsAreForwardedFromJSONString() throws {
            struct Tag: JSONObjectEncodable, JSONValueDecodable, Equatable {
                let name: String
                init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
                    guard let name = json?.jsonValue.object?["name"]?.string else {
                        warnings?.log("Missing 'name'", model: Tag.self)
                        return nil
                    }
                    self.name = name
                }

                var jsonObject: [String: JSONValue] {
                    ["name": .string(name)]
                }
            }

            let logger = ListWarningLogger()
            #expect(throws: JSONError.self) {
                try Tag(jsonString: #"{"other": "field"}"#, warnings: logger)
            }
            #expect(logger.warnings.count == 1)
        }
    }

    enum ReadResultExtensions {
        struct NonOptionalData {
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

        struct OptionalData {
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
