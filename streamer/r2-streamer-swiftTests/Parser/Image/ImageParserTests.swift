//
//  ImageParserTests.swift
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

class ImageParserTests: XCTestCase {

    let fixtures = Fixtures()
    var parser: ImageParser!
    
    var cbzAsset: FileAsset!
    var cbzFetcher: Fetcher!
    
    var jpgAsset: FileAsset!
    var jpgFetcher: Fetcher!

    override func setUpWithError() throws {
        parser = ImageParser()
        
        cbzAsset = FileAsset(url: fixtures.url(for: "futuristic_tales.cbz"))
        cbzFetcher = try ArchiveFetcher(url: cbzAsset.url)
        
        jpgAsset = FileAsset(url: fixtures.url(for: "futuristic_tales/Cory Doctorow's Futuristic Tales of the Here and Now/a-fc.jpg"))
        jpgFetcher = FileFetcher(href: "/a-fc.jpg", path: jpgAsset.url)
    }
    
    func testRefusesNonBitmapBased() throws {
        let asset = FileAsset(url: fixtures.url(for: "cc-shared-culture.epub"))
        let fetcher = try ArchiveFetcher(url: asset.url)
        XCTAssertNil(try parser.parse(asset: asset, fetcher: fetcher, warnings: nil))
    }
    
    func testAcceptsCBZ() {
        XCTAssertNotNil(try parser.parse(asset: cbzAsset, fetcher: cbzFetcher, warnings: nil))
    }
    
    func testAcceptsJPG() {
        XCTAssertNotNil(try parser.parse(asset: jpgAsset, fetcher: jpgFetcher, warnings: nil))
    }

    /// The reading order is sorted alphabetically, ignores Thumbs.db, hidden files and non-bitmap
    /// files.
    func testReadingOrderIsSortedAlphabetically() throws {
        let publication = try XCTUnwrap(parser.parse(asset: cbzAsset, fetcher: cbzFetcher, warnings: nil)?.build())
        
        XCTAssertEqual(publication.readingOrder, [
            Link(href: "/Cory Doctorow's Futuristic Tales of the Here and Now/a-fc.jpg", type: "image/jpeg", rels: [.cover], properties: Properties(["compressedLength": 145844])),
            Link(href: "/Cory Doctorow's Futuristic Tales of the Here and Now/x-002.jpg", type: "image/jpeg", properties: Properties(["compressedLength": 178836])),
            Link(href: "/Cory Doctorow's Futuristic Tales of the Here and Now/x-003.jpg", type: "image/jpeg", properties: Properties(["compressedLength": 135129])),
            Link(href: "/Cory Doctorow's Futuristic Tales of the Here and Now/x-153.jpg", type: "image/jpeg", properties: Properties(["compressedLength": 203443])),
            Link(href: "/Cory Doctorow's Futuristic Tales of the Here and Now/z-bc.jpg", type: "image/jpeg", properties: Properties(["compressedLength": 130033]))
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
                href: "/Cory Doctorow's Futuristic Tales of the Here and Now/a-fc.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 0,
                    position: 1
                )
            ),
            Locator(
                href: "/Cory Doctorow's Futuristic Tales of the Here and Now/x-002.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 1/5.0,
                    position: 2
                )
            ),
            Locator(
                href: "/Cory Doctorow's Futuristic Tales of the Here and Now/x-003.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 2/5.0,
                    position: 3
                )
            ),
            Locator(
                href: "/Cory Doctorow's Futuristic Tales of the Here and Now/x-153.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 3/5.0,
                    position: 4
                )
            ),
            Locator(
                href: "/Cory Doctorow's Futuristic Tales of the Here and Now/z-bc.jpg",
                type: "image/jpeg",
                locations: .init(
                    totalProgression: 4/5.0,
                    position: 5
                )
            )
        ])
    }
    
}
