//
//  ReadiumWebPubParserTests.swift
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

class ReadiumWebPubParserTests: XCTestCase {

    let fixtures = Fixtures()
    var parser: ReadiumWebPubParser!
    
    var manifestFile: File!
    var manifestFetcher: Fetcher!
    
    var packageFile: File!
    var packageFetcher: Fetcher!
    
    override func setUpWithError() throws {
        parser = ReadiumWebPubParser()

        manifestFile = File(url: fixtures.url(for: "flatland.json"))
        manifestFetcher = FileFetcher(href: "/flatland.json", path: manifestFile.url)
        
        packageFile = File(url: fixtures.url(for: "audiotest.lcpa"))
        packageFetcher = try ArchiveFetcher(url: packageFile.url)
    }
    
    func testRefusesNonReadiumWebPub() throws {
        let file = File(url: fixtures.url(for: "cc-shared-culture.epub"))
        let fetcher = try ArchiveFetcher(url: file.url)
        XCTAssertNil(try parser.parse(file: file, fetcher: fetcher))
    }
    
    func testAcceptsManifest() {
        XCTAssertNotNil(try parser.parse(file: manifestFile, fetcher: manifestFetcher))
    }
    
    func testAcceptsPackage() {
        XCTAssertNotNil(try parser.parse(file: packageFile, fetcher: packageFetcher))
    }

}
