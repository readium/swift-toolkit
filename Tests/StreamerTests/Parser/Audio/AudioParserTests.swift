//
//  AudioParserTests.swift
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

class AudioParserTests: XCTestCase {

    let fixtures = Fixtures()
    var parser: AudioParser!
    
    var zabAsset: FileAsset!
    var zabFetcher: Fetcher!
    
    var mp3Asset: FileAsset!
    var mp3Fetcher: Fetcher!
    
    override func setUpWithError() throws {
        parser = AudioParser()
        
        zabAsset = FileAsset(url: fixtures.url(for: "audiotest.zab"))
        zabFetcher = try ArchiveFetcher(url: zabAsset.url)
        
        mp3Asset = FileAsset(url: fixtures.url(for: "audiotest/Test Audiobook/Latin.mp3"))
        mp3Fetcher = FileFetcher(href: "/Latin.mp3", path: mp3Asset.url)
    }
    
    func testRefusesNonAudioBased() throws {
        let asset = FileAsset(url: fixtures.url(for: "cc-shared-culture.epub"))
        let fetcher = try ArchiveFetcher(url: asset.url)
        XCTAssertNil(try parser.parse(asset: asset, fetcher: fetcher, warnings: nil))
    }
    
    func testAcceptsZAB() {
        XCTAssertNotNil(try parser.parse(asset: zabAsset, fetcher: zabFetcher, warnings: nil))
    }
    
    func testAcceptsMP3() {
        XCTAssertNotNil(try parser.parse(asset: mp3Asset, fetcher: mp3Fetcher, warnings: nil))
    }
    
    /// The reading order is sorted alphabetically, ignores Thumbs.db, hidden files and non-audio
    /// files.
    func testReadingOrderIsSortedAlphabetically() throws {
        let publication = try XCTUnwrap(parser.parse(asset: zabAsset, fetcher: zabFetcher, warnings: nil)?.build())
        
        XCTAssertEqual(publication.readingOrder.map { $0.href }, [
            "/Test Audiobook/gtr-jazz.mp3",
            "/Test Audiobook/Latin.mp3",
            "/Test Audiobook/vln-lin-cs.mp3"
        ])
    }
    
    func testHasNoCover() throws {
        let publication = try XCTUnwrap(parser.parse(asset: zabAsset, fetcher: zabFetcher, warnings: nil)?.build())
        XCTAssertNil(publication.link(withRel: .cover))
    }
    
    func testComputeTitleFromArchiveRootDirectory() throws {
        let publication = try XCTUnwrap(parser.parse(asset: zabAsset, fetcher: zabFetcher, warnings: nil)?.build())
        XCTAssertEqual(publication.metadata.title, "Test Audiobook")
    }
    
    func testHasNoPositions() throws {
        let publication = try XCTUnwrap(parser.parse(asset: zabAsset, fetcher: zabFetcher, warnings: nil)?.build())
        
        XCTAssertEqual(publication.positions.count, 0)
    }

}
