//
//  FetcherTests.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 15/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
import R2Shared
@testable import R2Streamer

class FetcherTests: XCTestCase {
    
    func testGuessTitleWithoutDirectories() {
        let fetcher = TestFetcher(hrefs: ["/a.txt", "/b.png"])
        XCTAssertNil(fetcher.guessTitle())
    }
    
    func testGuessTitleWithOneRootDirectory() {
        let fetcher = TestFetcher(hrefs: ["/Root Directory/b.png", "/Root Directory/dir/c.png"])
        XCTAssertEqual(fetcher.guessTitle(), "Root Directory")
    }
    
    func testGuessTitleWithOneRootDirectoryButRootFiles() {
        let fetcher = TestFetcher(hrefs: ["/a.txt", "/Root Directory/b.png", "/Root Directory/dir/c.png"])
        XCTAssertNil(fetcher.guessTitle())
    }
    
    func testGuessTitleWithOneRootDirectoryButRootFilesWithIgnore() {
        let fetcher = TestFetcher(hrefs: ["/.hidden", "/Root Directory/b.png", "/Root Directory/dir/c.png"])
        XCTAssertEqual(fetcher.guessTitle(ignoring: { $0.href == "/.hidden" }), "Root Directory")
        
    }
    
    func testGuessTitleWithSeveralDirectories() {
        let fetcher = TestFetcher(hrefs: ["/a.txt", "/dir1/b.png", "/dir2/c.png"])
        XCTAssertNil(fetcher.guessTitle())
    }
    
    func testGuessTitleIgnoresSingleFiles() {
        let fetcher = TestFetcher(hrefs: ["/single"])
        XCTAssertNil(fetcher.guessTitle())
    }
    
}

private struct TestFetcher: Fetcher {

    init(hrefs: [String]) {
        self.links = hrefs.map { Link(href: $0) }
    }
    
    var links: [Link]
    
    func get(_ link: Link) -> Resource {
        fatalError()
    }
    
    func close() {}

}
