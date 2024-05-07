//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class ImageParserTests: XCTestCase {
    let fixtures = Fixtures()
    var parser: ImageParser!

    var cbzAsset: FileAsset!
    var cbzFetcher: Fetcher!

    var jpgAsset: FileAsset!
    var jpgFetcher: Fetcher!

    override func setUpWithError() throws {
        parser = ImageParser()

        cbzAsset = FileAsset(file: fixtures.url(for: "futuristic_tales.cbz"))
        cbzFetcher = try ArchiveFetcher(file: cbzAsset.file)

        jpgAsset = FileAsset(file: fixtures.url(for: "futuristic_tales/Cory Doctorow's Futuristic Tales of the Here and Now/a-fc.jpg"))
        jpgFetcher = FileFetcher(href: RelativeURL(path: "a-fc.jpg")!, file: jpgAsset.file)
    }

    func testRefusesNonBitmapBased() throws {
        let asset = FileAsset(file: fixtures.url(for: "audiotest.zab"))
        let fetcher = try ArchiveFetcher(file: asset.file)
        XCTAssertNil(try parser.parse(asset: asset, fetcher: fetcher, warnings: nil))
    }

    func testAcceptsCBZ() {
        XCTAssertNotNil(try parser.parse(asset: cbzAsset, fetcher: cbzFetcher, warnings: nil))
    }

    func testAcceptsJPG() {
        XCTAssertNotNil(try parser.parse(asset: jpgAsset, fetcher: jpgFetcher, warnings: nil))
    }

    func testConformsToDivina() throws {
        let publication = try XCTUnwrap(parser.parse(asset: cbzAsset, fetcher: cbzFetcher, warnings: nil)?.build())

        XCTAssertEqual(publication.metadata.conformsTo, [.divina])
    }

    /// The reading order is sorted alphabetically, ignores Thumbs.db, hidden files and non-bitmap
    /// files.
    func testReadingOrderIsSortedAlphabetically() throws {
        let publication = try XCTUnwrap(parser.parse(asset: cbzAsset, fetcher: cbzFetcher, warnings: nil)?.build())

        XCTAssertEqual(publication.readingOrder.map(\.href), [
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/a-fc.jpg",
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-002.jpg",
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-003.jpg",
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-153.jpg",
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/z-bc.jpg",
        ])
    }

    func testFirstReadingOrderItemIsCover() throws {
        let publication = try XCTUnwrap(parser.parse(asset: cbzAsset, fetcher: cbzFetcher, warnings: nil)?.build())
        let cover = try XCTUnwrap(publication.link(withRel: .cover))
        XCTAssertEqual(publication.readingOrder.first, cover)
    }

    func testComputeTitleFromArchiveRootDirectory() throws {
        let publication = try XCTUnwrap(parser.parse(asset: cbzAsset, fetcher: cbzFetcher, warnings: nil)?.build())
        XCTAssertEqual(publication.metadata.title, "Cory Doctorow's Futuristic Tales of the Here and Now")
    }

    func testPositions() throws {
        let publication = try XCTUnwrap(parser.parse(asset: cbzAsset, fetcher: cbzFetcher, warnings: nil)?.build())

        XCTAssertEqual(publication.positions, [
            Locator(
                href: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/a-fc.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 0,
                    position: 1
                )
            ),
            Locator(
                href: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-002.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 1 / 5.0,
                    position: 2
                )
            ),
            Locator(
                href: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-003.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 2 / 5.0,
                    position: 3
                )
            ),
            Locator(
                href: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-153.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 3 / 5.0,
                    position: 4
                )
            ),
            Locator(
                href: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/z-bc.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 4 / 5.0,
                    position: 5
                )
            ),
        ])
    }
}
