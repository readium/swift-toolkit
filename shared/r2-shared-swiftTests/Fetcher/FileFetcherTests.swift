//
//  FileFetcherTests.swift
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

class FileFetcherTests: XCTestCase {
    
    let fixtures = Fixtures(path: "Fetcher")
    var fetcher: FileFetcher!
    
    override func setUp() {
        fetcher = FileFetcher(paths: [
            "/file_href": fixtures.url(for: "text.txt"),
            "/dir_href": fixtures.url(for: "directory")
        ])
    }
    
    func testLinks() {
        XCTAssertEqual(fetcher.links, [
            Link(href: "/dir_href/subdirectory/hello.mp3", type: "audio/mpeg"),
            Link(href: "/dir_href/subdirectory/text2.txt", type: "text/plain"),
            Link(href: "/dir_href/text1.txt", type: "text/plain"),
            Link(href: "/file_href", type: "text/plain")
        ])
    }
    
    func testReadFile() {
        let resource = fetcher.get(Link(href: "/file_href"))
        let result = resource.read()
        let string = String(data: try! result.get(), encoding: .utf8)
        XCTAssertEqual(string, "text\n")
    }
    
    func testReadFileInDirectory() {
        let resource = fetcher.get(Link(href: "/dir_href/text1.txt"))
        let result = resource.read()
        let string = String(data: try! result.get(), encoding: .utf8)
        XCTAssertEqual(string, "text1\n")
    }
    
    func testReadFileInSubdirectory() {
        let resource = fetcher.get(Link(href: "/dir_href/subdirectory/text2.txt"))
        let result = resource.read()
        let string = String(data: try! result.get(), encoding: .utf8)
        XCTAssertEqual(string, "text2\n")
    }
    
    func testReadResourceRange() {
        let resource = fetcher.get(Link(href: "/file_href"))
        let result = resource.read(range: 0..<3)
        let string = String(data: try! result.get(), encoding: .utf8)
        XCTAssertEqual(string, "tex")
    }
    
    func testOutOfRangeIndexesAreClampedToAvailableLength() {
        let resource = fetcher.get(Link(href: "/file_href"))
        let result = resource.read(range: 2..<60)
        let string = String(data: try! result.get(), encoding: .utf8)
        XCTAssertEqual(string, "xt\n")
    }
    
    func testReadingMissingFileReturnsNotFound() {
        let resource = fetcher.get(Link(href: "/unknown"))
        let result = resource.read()
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(ResourceError.notFound, error as? ResourceError)
        }
    }
    
    func testReadingFileOutsideDirectoryReturnsNotFound() {
        let resource = fetcher.get(Link(href: "/dir_href/../text.txt"))
        let result = resource.read()
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(ResourceError.notFound, error as? ResourceError)
        }
    }
    
    func testReadingDirectoryReturnsNotFound() {
        let resource = fetcher.get(Link(href: "/dir_href"))
        let result = resource.read()
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(ResourceError.notFound, error as? ResourceError)
        }
    }
    
    func testComputingLength() {
        let resource = fetcher.get(Link(href: "/file_href"))
        XCTAssertEqual(try! resource.length.get(), 5)
    }

    func testComputingLengthForMissingEntryReturnsNotFound() {
        let resource = fetcher.get(Link(href: "/unknown"))
        let result = resource.length
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(ResourceError.notFound, error as? ResourceError)
        }
    }
    
}
