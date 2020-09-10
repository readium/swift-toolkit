//
//  ContentLayoutTests.swift
//  r2-shared-swift
//
//  Created by Mickaël on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class ContentLayoutTests: XCTestCase {

    func testParseFallbacksOnLTR() {
        XCTAssertEqual(ContentLayout(language: ""), .ltr)
        XCTAssertEqual(ContentLayout(language: "foobar"), .ltr)
    }

    func testParseFallbacksOnTheProvidedReadingProgression() {
        XCTAssertEqual(ContentLayout(language: "foobar", readingProgression: .rtl), .rtl)
    }

    func testParseFromRTLLanguage() {
        XCTAssertEqual(ContentLayout(language: "AR"), .rtl)
        XCTAssertEqual(ContentLayout(language: "FA"), .rtl)
        XCTAssertEqual(ContentLayout(language: "HE"), .rtl)
        XCTAssertEqual(ContentLayout(language: "HE", readingProgression: .ltr), .ltr)
    }

    func testParseFromCJKLanguage() {
        XCTAssertEqual(ContentLayout(language: "ZH"), .cjkHorizontal)
        XCTAssertEqual(ContentLayout(language: "JA"), .cjkHorizontal)
        XCTAssertEqual(ContentLayout(language: "KO"), .cjkHorizontal)
        XCTAssertEqual(ContentLayout(language: "ZH", readingProgression: .ltr), .cjkHorizontal)
        XCTAssertEqual(ContentLayout(language: "JA", readingProgression: .ltr), .cjkHorizontal)
        XCTAssertEqual(ContentLayout(language: "KO", readingProgression: .ltr), .cjkHorizontal)
        XCTAssertEqual(ContentLayout(language: "ZH", readingProgression: .rtl), .cjkVertical)
        XCTAssertEqual(ContentLayout(language: "JA", readingProgression: .rtl), .cjkVertical)
        XCTAssertEqual(ContentLayout(language: "KO", readingProgression: .rtl), .cjkVertical)
    }
    
    func testParseIgnoresCase() {
        XCTAssertEqual(ContentLayout(language: "ar"), .rtl)
    }
    
    func testParseIgnoresRegion() {
        XCTAssertEqual(ContentLayout(language: "AR-FOOBAR"), .rtl)
    }
    
    func testGetReadingProgression() {
        XCTAssertEqual(ContentLayout.ltr.readingProgression, .ltr)
        XCTAssertEqual(ContentLayout.rtl.readingProgression, .rtl)
        XCTAssertEqual(ContentLayout.cjkHorizontal.readingProgression, .ltr)
        XCTAssertEqual(ContentLayout.cjkVertical.readingProgression, .rtl)
    }

}
