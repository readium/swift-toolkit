//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class AudioParserTests: XCTestCase {
    let fixtures = Fixtures()

    var parser: AudioParser!

    var zabAsset: Asset!
    var mp3Asset: Asset!

    override func setUp() async throws {
        parser = AudioParser(assetRetriever: AssetRetriever(httpClient: DefaultHTTPClient()))

        zabAsset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "audiotest.zab")),
            format: Format(specifications: .zip, .informalAudiobook, mediaType: .zab, fileExtension: "zab")
        ).get())

        mp3Asset = .resource(ResourceAsset(
            resource: FileResource(file: fixtures.url(for: "audiotest/Test Audiobook/Latin.mp3")),
            format: Format(specifications: .mp3, mediaType: .mp3, fileExtension: "mp3")
        ))
    }

    func testRefusesNonAudioBased() async throws {
        let asset: Asset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "futuristic_tales.cbz")),
            format: Format(specifications: .zip, .informalComic, mediaType: .cbz, fileExtension: "cbz")
        ).get())

        do {
            _ = try await parser.parse(asset: asset, warnings: nil).get()
        } catch PublicationParseError.formatNotSupported {
            return
        } catch {}

        XCTFail("Expected an error")
    }

    func testAcceptsZAB() async throws {
        let result = try await parser.parse(asset: zabAsset, warnings: nil).get()
        XCTAssertNotNil(result)
    }

    func testAcceptsMP3() async throws {
        let result = try await parser.parse(asset: mp3Asset, warnings: nil).get()
        XCTAssertNotNil(result)
    }

    func testConformsToAudiobook() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()
        XCTAssertEqual(publication.metadata.conformsTo, [.audiobook])
    }

    /// The reading order is sorted alphabetically, ignores Thumbs.db, hidden files and non-audio
    /// files.
    func testReadingOrderIsSortedAlphabetically() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()

        XCTAssertEqual(publication.readingOrder.map(\.href), [
            "Test%20Audiobook/gtr-jazz.mp3",
            "Test%20Audiobook/Latin.mp3",
            "Test%20Audiobook/vln-lin-cs.mp3",
        ])
    }

    func testHasNoCover() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()
        XCTAssertNil(publication.linkWithRel(.cover))
    }

    func testComputeTitleFromArchiveRootDirectory() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()
        XCTAssertEqual(publication.metadata.title, "Test Audiobook")
    }

    func testHasNoPositions() async throws {
        let publication = try await parser.parse(asset: zabAsset, warnings: nil).get().build()
        let result = try await publication.positions().get()
        XCTAssertEqual(result.count, 0)
    }
}
