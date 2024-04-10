//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class AudioParserTests: XCTestCase {
    let fixtures = Fixtures()
    var parser: AudioParser!

    var zabAsset: FileAsset!
    var zabFetcher: Fetcher!

    var mp3Asset: FileAsset!
    var mp3Fetcher: Fetcher!

    override func setUpWithError() throws {
        parser = AudioParser()

        zabAsset = FileAsset(file: fixtures.url(for: "audiotest.zab"))
        zabFetcher = try ArchiveFetcher(file: zabAsset.file)

        mp3Asset = FileAsset(file: fixtures.url(for: "audiotest/Test Audiobook/Latin.mp3"))
        mp3Fetcher = FileFetcher(href: RelativeURL(path: "Latin.mp3")!, file: mp3Asset.file)
    }

    func testRefusesNonAudioBased() throws {
        let asset = FileAsset(file: fixtures.url(for: "futuristic_tales.cbz"))
        let fetcher = try ArchiveFetcher(file: asset.file)
        XCTAssertNil(try parser.parse(asset: asset, fetcher: fetcher, warnings: nil))
    }

    func testAcceptsZAB() {
        XCTAssertNotNil(try parser.parse(asset: zabAsset, fetcher: zabFetcher, warnings: nil))
    }

    func testAcceptsMP3() {
        XCTAssertNotNil(try parser.parse(asset: mp3Asset, fetcher: mp3Fetcher, warnings: nil))
    }

    func testConformsToAudiobook() throws {
        let publication = try XCTUnwrap(parser.parse(asset: zabAsset, fetcher: zabFetcher, warnings: nil)?.build())

        XCTAssertEqual(publication.metadata.conformsTo, [.audiobook])
    }

    /// The reading order is sorted alphabetically, ignores Thumbs.db, hidden files and non-audio
    /// files.
    func testReadingOrderIsSortedAlphabetically() throws {
        let publication = try XCTUnwrap(parser.parse(asset: zabAsset, fetcher: zabFetcher, warnings: nil)?.build())

        XCTAssertEqual(publication.readingOrder.map(\.href), [
            "Test%20Audiobook/gtr-jazz.mp3",
            "Test%20Audiobook/Latin.mp3",
            "Test%20Audiobook/vln-lin-cs.mp3",
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
