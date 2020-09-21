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
    
    var zabFile: File!
    var zabFetcher: Fetcher!
    
    var mp3File: File!
    var mp3Fetcher: Fetcher!
    
    override func setUpWithError() throws {
        parser = AudioParser()
        
        zabFile = File(url: fixtures.url(for: "audiotest.zab"))
        zabFetcher = try ArchiveFetcher(url: zabFile.url)
        
        mp3File = File(url: fixtures.url(for: "audiotest/Test Audiobook/Latin.mp3"))
        mp3Fetcher = FileFetcher(href: "/Latin.mp3", path: mp3File.url)
    }
    
    func testRefusesNonAudioBased() throws {
        let file = File(url: fixtures.url(for: "cc-shared-culture.epub"))
        let fetcher = try ArchiveFetcher(url: file.url)
        XCTAssertNil(try parser.parse(file: file, fetcher: fetcher))
    }
    
    func testAcceptsZAB() {
        XCTAssertNotNil(try parser.parse(file: zabFile, fetcher: zabFetcher))
    }
    
    func testAcceptsMP3() {
        XCTAssertNotNil(try parser.parse(file: mp3File, fetcher: mp3Fetcher))
    }
    
    /// The reading order is sorted alphabetically, ignores Thumbs.db, hidden files and non-audio
    /// files.
    func testReadingOrderIsSortedAlphabetically() throws {
        let publication = try XCTUnwrap(parser.parse(file: zabFile, fetcher: zabFetcher)?.build())
        
        XCTAssertEqual(publication.readingOrder, [
            Link(href: "/Test Audiobook/gtr-jazz.mp3", type: "audio/mpeg"),
            Link(href: "/Test Audiobook/Latin.mp3", type: "audio/mpeg"),
            Link(href: "/Test Audiobook/vln-lin-cs.mp3", type: "audio/mpeg")
        ])
    }
    
    func testHasNoCover() throws {
        let publication = try XCTUnwrap(parser.parse(file: zabFile, fetcher: zabFetcher)?.build())
        XCTAssertNil(publication.link(withRel: .cover))
    }
    
    func testComputeTitleFromArchiveRootDirectory() throws {
        let publication = try XCTUnwrap(parser.parse(file: zabFile, fetcher: zabFetcher)?.build())
        XCTAssertEqual(publication.metadata.title, "Test Audiobook")
    }
    
    func testHasNoPositions() throws {
        let publication = try XCTUnwrap(parser.parse(file: zabFile, fetcher: zabFetcher)?.build())
        
        XCTAssertEqual(publication.positions.count, 0)
    }

}
