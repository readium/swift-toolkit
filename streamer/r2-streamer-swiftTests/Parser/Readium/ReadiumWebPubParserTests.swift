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
    
    var manifestAsset: FileAsset!
    var manifestFetcher: Fetcher!
    
    var packageAsset: FileAsset!
    var packageFetcher: Fetcher!
    
    var lcpdfAsset: FileAsset!
    var lcpdfFetcher: Fetcher!
    
    override func setUpWithError() throws {
        parser = ReadiumWebPubParser()

        manifestAsset = FileAsset(url: fixtures.url(for: "flatland.json"))
        manifestFetcher = FileFetcher(href: "/flatland.json", path: manifestAsset.url)
        
        packageAsset = FileAsset(url: fixtures.url(for: "audiotest.lcpa"))
        packageFetcher = try ArchiveFetcher(url: packageAsset.url)
        
        lcpdfAsset = FileAsset(url: fixtures.url(for: "daisy.lcpdf"))
        lcpdfFetcher = try ArchiveFetcher(url: lcpdfAsset.url)
    }
    
    func testRefusesNonReadiumWebPub() throws {
        let asset = FileAsset(url: fixtures.url(for: "cc-shared-culture.epub"))
        let fetcher = try ArchiveFetcher(url: asset.url)
        XCTAssertNil(try parser.parse(asset: asset, fetcher: fetcher, warnings: nil))
    }
    
    func testAcceptsManifest() {
        XCTAssertNotNil(try parser.parse(asset: manifestAsset, fetcher: manifestFetcher, warnings: nil))
    }
    
    func testAcceptsPackage() {
        XCTAssertNotNil(try parser.parse(asset: packageAsset, fetcher: packageFetcher, warnings: nil))
    }
    
    /// The `Link`s' hrefs are normalized to the `self` link for a manifest.
    func testHrefsAreNormalizedToSelfForManifests() throws {
        let publication = try XCTUnwrap(try parser.parse(asset: manifestAsset, fetcher: manifestFetcher, warnings: nil)?.build())

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
        let publication = try XCTUnwrap(parser.parse(asset: packageAsset, fetcher: packageFetcher, warnings: nil)?.build())

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
