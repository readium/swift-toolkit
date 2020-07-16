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
    
    var lcpdfFile: File!
    var lcpdfFetcher: Fetcher!
    
    override func setUpWithError() throws {
        parser = ReadiumWebPubParser()

        manifestFile = File(url: fixtures.url(for: "flatland.json"))
        manifestFetcher = FileFetcher(href: "/flatland.json", path: manifestFile.url)
        
        packageFile = File(url: fixtures.url(for: "audiotest.lcpa"))
        packageFetcher = try ArchiveFetcher(url: packageFile.url)
        
        lcpdfFile = File(url: fixtures.url(for: "daisy.lcpdf"))
        lcpdfFetcher = try ArchiveFetcher(url: lcpdfFile.url)
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
    
    /// The `Link`s' hrefs are normalized to the `self` link for a manifest.
    func testHrefsAreNormalizedToSelfForManifests() throws {
        let publication = try XCTUnwrap(parser.parse(file: manifestFile, fetcher: manifestFetcher)?.build())

        XCTAssertEqual(
            publication.readingOrder.map { $0.href },
            [
                "http://www.archive.org/download/flatland_rg_librivox/flatland_1_abbott.mp3",
                "https://readium.org/webpub-manifest/examples/Flatland/flatland_2_abbott.mp3",
                "https://readium.org/flatland_3_abbott.mp3"
            ]
        )
    }
    
    /// The `Link`s' hrefs are normalized to `/` for a package.
    func testHrefsAreNormalizedToRootForPackages() throws {
        let publication = try XCTUnwrap(parser.parse(file: packageFile, fetcher: packageFetcher)?.build())

        XCTAssertEqual(
            publication.readingOrder.map { $0.href },
            [
                "http://readium.org/audio/gtr-jazz.mp3",
                "/audio/Latin.mp3",
                "/audio/oboe-bassoon.mp3"
            ]
        )
    }

}
