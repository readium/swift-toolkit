//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class JSONValueTests: XCTestCase {
    func testInitializeFromNil() {
        XCTAssertNil(JSONValue(nil as Any?))
    }

    func testInitializeFromBool() {
        XCTAssertEqual(JSONValue(true), .bool(true))
        XCTAssertEqual(JSONValue(false), .bool(false))
    }

    func testInitializeFromString() {
        XCTAssertEqual(JSONValue("hello"), .string("hello"))
    }

    func testInitializeFromInt() {
        XCTAssertEqual(JSONValue(42), .integer(42))
    }

    func testInitializeFromUInt64() {
        // Small values are canonicalized to .integer if they fit.
        XCTAssertEqual(JSONValue(UInt64(42)), .integer(42))
        // Large values that don't fit in Int (on the current platform) use .double.
        let largeValue = UInt64.max
        XCTAssertEqual(JSONValue(largeValue), .double(Double(largeValue)))
    }

    func testInitializeFromDouble() {
        XCTAssertEqual(JSONValue(3.14), .double(3.14))
    }

    func testInitializeFromArray() {
        let array: [Any] = ["hello", 42, true]
        XCTAssertEqual(JSONValue(array), .array([.string("hello"), .integer(42), .bool(true)]))
    }

    func testInitializeFromObject() {
        let dict: [String: Any] = ["key": "value", "count": 1]
        XCTAssertEqual(JSONValue(dict), .object(["key": .string("value"), "count": .integer(1)]))
    }

    func testInitializeFromNSNull() {
        XCTAssertEqual(JSONValue(NSNull()), .null)
    }

    func testInitializeFromNSNumber() {
        XCTAssertEqual(JSONValue(NSNumber(value: true)), .bool(true))
        XCTAssertEqual(JSONValue(NSNumber(value: 42)), .integer(42))
        XCTAssertEqual(JSONValue(NSNumber(value: 3.14)), .double(3.14))
    }

    func testAnyProperty() {
        XCTAssertTrue(JSONValue.null.any is NSNull)
        XCTAssertEqual(JSONValue.bool(true).any as? Bool, true)
        XCTAssertEqual(JSONValue.string("hello").any as? String, "hello")
        XCTAssertEqual(JSONValue.integer(42).any as? Int, 42)
        XCTAssertEqual(JSONValue.double(3.14).any as? Double, 3.14)
        XCTAssertEqual((JSONValue.array([.integer(1)]).any as? [Int])?[0], 1)
        XCTAssertEqual((JSONValue.object(["k": .integer(1)]).any as? [String: Int])?["k"], 1)
    }

    func testAccessors() {
        let val: JSONValue = .integer(42)
        XCTAssertEqual(val.integer, 42)
        XCTAssertEqual(val.uint64, 42)
        XCTAssertEqual(val.double, 42.0)
        XCTAssertNil(val.string)

        let stringVal: JSONValue = .string("test")
        XCTAssertEqual(stringVal.string, "test")
        XCTAssertNil(stringVal.integer)
    }

    func testLiteralConformance() {
        let null: JSONValue = nil
        XCTAssertEqual(null, .null)

        let bool: JSONValue = true
        XCTAssertEqual(bool, .bool(true))

        let string: JSONValue = "hello"
        XCTAssertEqual(string, .string("hello"))

        let int: JSONValue = 42
        XCTAssertEqual(int, .integer(42))

        let double: JSONValue = 3.14
        XCTAssertEqual(double, .double(3.14))

        let array: JSONValue = ["a", 1]
        XCTAssertEqual(array, .array([.string("a"), .integer(1)]))

        let object: JSONValue = ["k": "v"]
        XCTAssertEqual(object, .object(["k": .string("v")]))
    }

    func testCodable() throws {
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

        XCTAssertEqual(original, decoded)
    }

    func testAsJSONValue() {
        let data = #"{"foo": "bar"}"#.data(using: .utf8)!
        let result: ReadResult<Data> = .success(data)
        XCTAssertEqual(result.asJSONValue(), .success(.object(["foo": .string("bar")])))
    }

    func testAsJSONObjectValue() {
        let data = #"{"foo": "bar"}"#.data(using: .utf8)!
        let result: ReadResult<Data> = .success(data)
        XCTAssertEqual(result.asJSONObjectValue(), .success(["foo": .string("bar")]))
    }

    func testAsJSONValueOptional() {
        let data = #"{"foo": "bar"}"#.data(using: .utf8)!
        let result: ReadResult<Data?> = .success(data)
        XCTAssertEqual(result.asJSONValue(), .success(.object(["foo": .string("bar")])))

        let nilResult: ReadResult<Data?> = .success(nil)
        XCTAssertEqual(nilResult.asJSONValue(), .success(nil))
    }

    func testAsJSONObjectValueOptional() {
        let data = #"{"foo": "bar"}"#.data(using: .utf8)!
        let result: ReadResult<Data?> = .success(data)
        XCTAssertEqual(result.asJSONObjectValue(), .success(["foo": .string("bar")]))

        let nilResult: ReadResult<Data?> = .success(nil)
        XCTAssertEqual(nilResult.asJSONObjectValue(), .success(nil))
    }

    func testInitializeFromNestedCollections() {
        let dict: [String: Any] = [
            "nested": [
                "array": [1, 2, 3] as [Any],
            ] as [String: Any],
        ]
        XCTAssertEqual(JSONValue(dict), .object([
            "nested": .object([
                "array": .array([.integer(1), .integer(2), .integer(3)]),
            ]),
        ]))
    }

    func testInitializeFastPath() {
        let original: JSONValue = .string("test")
        XCTAssertEqual(JSONValue(original), original)

        let object: [String: JSONValue] = ["k": .integer(1)]
        XCTAssertEqual(JSONValue(object), .object(object))

        let array: [JSONValue] = [.bool(true)]
        XCTAssertEqual(JSONValue(array), .array(array))
    }
}
