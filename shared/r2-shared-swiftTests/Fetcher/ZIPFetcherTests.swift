//
//  ZIPFetcherTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class ZIPFetcherTests: XCTestCase {
    
    let fixtures = Fixtures(path: "Fetcher")
    var fetcher: ZIPFetcher!

    override func setUp() {
        let url = fixtures.url(for: "epub.epub")
        fetcher = ZIPFetcher(archive: url)!
    }
    
    func testReadEntryFully() {
        let resource = fetcher.get(Link(href: "/mimetype"))
        let result = resource.read()
        let string = String(data: try! result.get(), encoding: .ascii)
        XCTAssertEqual(string, "application/epub+zip")
    }
    
    func testReadEntryRange() {
        let resource = fetcher.get(Link(href: "/mimetype"))
        let result = resource.read(range: 0..<11)
        let string = String(data: try! result.get(), encoding: .ascii)
        XCTAssertEqual(string, "application")
    }

    func testOutOfRangeIndexesAreClampedToAvailableLength() {
        let resource = fetcher.get(Link(href: "/mimetype"))
        let result = resource.read(range: 5..<60)
        let string = String(data: try! result.get(), encoding: .ascii)
        XCTAssertEqual(string, "cation/epub+zip")
    }
    
    func testReadingMissingEntryReturnsNotFound() {
        let resource = fetcher.get(Link(href: "/unknown"))
        let result = resource.read()
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(ResourceError.notFound, error as? ResourceError)
        }
    }
    
    func testComputingLength() {
        let resource = fetcher.get(Link(href: "/mimetype"))
        XCTAssertEqual(try! resource.length.get(), 20)
    }
    
    func testComputingLengthForMissingEntryReturnsNotFound() {
        let resource = fetcher.get(Link(href: "/unknown"))
        let result = resource.length
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(ResourceError.notFound, error as? ResourceError)
        }
    }
    
}
