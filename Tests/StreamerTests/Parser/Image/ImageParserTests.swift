//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class ImageParserTests: XCTestCase {
    let fixtures = Fixtures()
    var parser: ImageParser!

    var cbzAsset: Asset!
    var jpgAsset: Asset!

    override func setUp() async throws {
        parser = ImageParser(assetRetriever: AssetRetriever(httpClient: DefaultHTTPClient()))

        cbzAsset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "futuristic_tales.cbz")),
            format: Format(specifications: .zip, .informalComic, mediaType: .cbz, fileExtension: "cbz")
        ).get())

        jpgAsset = .resource(ResourceAsset(
            resource: FileResource(file: fixtures.url(for: "futuristic_tales/Cory Doctorow's Futuristic Tales of the Here and Now/a-fc.jpg")),
            format: Format(specifications: .jpeg, mediaType: .jpeg, fileExtension: "jpeg")
        ))
    }

    func testRefusesNonBitmapBased() async throws {
        let asset: Asset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "audiotest.zab")),
            format: Format(specifications: .zip, .informalAudiobook, mediaType: .zab, fileExtension: "zab")
        ).get())

        do {
            _ = try await parser.parse(asset: asset, warnings: nil).get()
        } catch PublicationParseError.formatNotSupported {
            return
        } catch {}

        XCTFail("Expected an error")
    }

    func testAcceptsCBZ() async throws {
        let result = try await parser.parse(asset: cbzAsset, warnings: nil).get()
        XCTAssertNotNil(result)
    }

    func testAcceptsJPG() async throws {
        let result = try await parser.parse(asset: jpgAsset, warnings: nil).get()
        XCTAssertNotNil(result)
    }

    func testConformsToDivina() async throws {
        let publication = try await parser.parse(asset: cbzAsset, warnings: nil).get().build()

        XCTAssertEqual(publication.metadata.conformsTo, [.divina])
    }

    /// The reading order is sorted alphabetically, ignores Thumbs.db, hidden files and non-bitmap
    /// files.
    func testReadingOrderIsSortedAlphabetically() async throws {
        let publication = try await parser.parse(asset: cbzAsset, warnings: nil).get().build()

        XCTAssertEqual(publication.readingOrder.map(\.href), [
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/a-fc.jpg",
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-002.jpg",
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-003.jpg",
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-153.jpg",
            "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/z-bc.jpg",
        ])
    }

    func testFirstReadingOrderItemIsCover() async throws {
        let publication = try await parser.parse(asset: cbzAsset, warnings: nil).get().build()
        let cover = try XCTUnwrap(publication.linkWithRel(.cover))
        XCTAssertEqual(publication.readingOrder.first, cover)
    }

    func testComputeTitleFromArchiveRootDirectory() async throws {
        let publication = try await parser.parse(asset: cbzAsset, warnings: nil).get().build()
        XCTAssertEqual(publication.metadata.title, "Cory Doctorow's Futuristic Tales of the Here and Now")
    }

    func testPositions() async throws {
        let publication = try await parser.parse(asset: cbzAsset, warnings: nil).get().build()

        let result = try await publication.positions().get()
        XCTAssertEqual(result, [
            Locator(
                href: AnyURL(string: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/a-fc.jpg")!,
                mediaType: .jpeg,
                locations: .init(
                    totalProgression: 0,
                    position: 1
                )
            ),
            Locator(
                href: AnyURL(string: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-002.jpg")!,
                mediaType: .jpeg,
                locations: .init(
                    totalProgression: 1 / 5.0,
                    position: 2
                )
            ),
            Locator(
                href: AnyURL(string: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-003.jpg")!,
                mediaType: .jpeg,
                locations: .init(
                    totalProgression: 2 / 5.0,
                    position: 3
                )
            ),
            Locator(
                href: AnyURL(string: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/x-153.jpg")!,
                mediaType: .jpeg,
                locations: .init(
                    totalProgression: 3 / 5.0,
                    position: 4
                )
            ),
            Locator(
                href: AnyURL(string: "Cory%20Doctorow's%20Futuristic%20Tales%20of%20the%20Here%20and%20Now/z-bc.jpg")!,
                mediaType: .jpeg,
                locations: .init(
                    totalProgression: 4 / 5.0,
                    position: 5
                )
            ),
        ])
    }
}
