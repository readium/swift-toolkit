//
//  WPSubjectTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 11.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class WPSubjectTests: XCTestCase {
    
    func testParseJSONString() {
        XCTAssertEqual(
            try? WPSubject(json: "Fantasy"),
            WPSubject(name: "Fantasy")
        )
    }
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WPSubject(json: ["name": "Science Fiction"]),
            WPSubject(name: "Science Fiction")
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? WPSubject(json: [
                "name": "Science Fiction",
                "sortAs": "science-fiction",
                "scheme": "http://scheme",
                "code": "CODE",
            ]),
            WPSubject(
                name: "Science Fiction",
                sortAs: "science-fiction",
                scheme: "http://scheme",
                code: "CODE"
            )
        )
    }
    
    func testParseJSONRequiresName() {
        XCTAssertThrowsError(try WPSubject(json: [
            "sortAs": "science-fiction"
        ]))
    }
    
    func testParseJSONArray() {
        XCTAssertEqual(
            [WPSubject](json: [
                "Fantasy",
                [
                    "name": "Science Fiction",
                    "scheme": "http://scheme"
                ]
            ]),
            [
                WPSubject(name: "Fantasy"),
                WPSubject(
                    name: "Science Fiction",
                    scheme: "http://scheme"
                )
            ]
        )
    }
    
    func testParseJSONArrayWhenNil() {
        XCTAssertEqual(
            [WPSubject](json: nil),
            []
        )
    }
    
    func testParseJSONArrayIgnoresInvalidSubjects() {
        XCTAssertEqual(
            [WPSubject](json: [
                "Fantasy",
                [
                    "code": "CODE"
                ]
            ]),
            [
                WPSubject(name: "Fantasy"),
            ]
        )
    }
    
    func testParseJSONArrayWhenString() {
        XCTAssertEqual(
            [WPSubject](json: "Fantasy"),
            [WPSubject(name: "Fantasy")]
        )
    }
    
    func testParseJSONArrayWhenSingleObject() {
        XCTAssertEqual(
            [WPSubject](json: [
                "name": "Fantasy",
                "code": "CODE"
            ]),
            [
                WPSubject(
                    name: "Fantasy",
                    code: "CODE"
                )
            ]
        )
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            WPSubject(name: "Fantasy").json,
            ["name": "Fantasy"]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            WPSubject(
                name: "Science Fiction",
                sortAs: "science-fiction",
                scheme: "http://scheme",
                code: "CODE"
            ).json,
            [
                "name": "Science Fiction",
                "sortAs": "science-fiction",
                "scheme": "http://scheme",
                "code": "CODE",
            ]
        )
    }
    
    func testGetJSONArray() {
        AssertJSONEqual(
            [
                WPSubject(name: "Fantasy"),
                WPSubject(
                    name: "Science Fiction",
                    scheme: "http://scheme"
                )
            ].json,
            [
                [
                    "name": "Fantasy"
                ],
                [
                    "name": "Science Fiction",
                    "scheme": "http://scheme"
                ]
            ]
        )
    }
    
}
