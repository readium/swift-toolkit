//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
    var cbzWithComicInfoAsset: Asset!
    var jpgAsset: Asset!

    override func setUp() async throws {
        parser = ImageParser(assetRetriever: AssetRetriever(httpClient: DefaultHTTPClient()))

        cbzAsset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "futuristic_tales.cbz")),
            format: Format(specifications: .zip, .informalComic, mediaType: .cbz, fileExtension: "cbz")
        ).get())

        cbzWithComicInfoAsset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "test-comicinfo.cbz")),
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

    func testParsesMetadataFromComicInfo() async throws {
        let publication = try await parser.parse(asset: cbzWithComicInfoAsset, warnings: nil).get().build()

        XCTAssertEqual(publication.metadata.conformsTo, [.divina])
        XCTAssertEqual(publication.metadata.title, "Test Comic Issue")
        XCTAssertEqual(publication.metadata.publishers.map(\.name), ["Test Publisher"])
        XCTAssertEqual(publication.metadata.languages, ["en"])
        XCTAssertEqual(publication.metadata.description, "A test comic for unit testing.")
        XCTAssertEqual(publication.metadata.subjects.map(\.name), ["Action", "Adventure"])
        XCTAssertEqual(publication.metadata.belongsToSeries.count, 1)
        XCTAssertEqual(publication.metadata.belongsToSeries.first?.name, "Test Series")
        XCTAssertEqual(publication.metadata.belongsToSeries.first?.position, 5.0)
        XCTAssertEqual(publication.metadata.authors.map(\.name), ["Test Writer"])
        XCTAssertEqual(publication.metadata.pencilers.map(\.name), ["Test Artist"])

        let coverLink = publication.linkWithRel(.cover)
        XCTAssertNotNil(coverLink)
        XCTAssertEqual(coverLink?.href, "TestComic/page-01.png")

        // Story starts at page-02 (index 1), which is different from cover (index 0)
        let startLink = publication.linkWithRel(.start)
        XCTAssertNotNil(startLink)
        XCTAssertEqual(startLink?.href, "TestComic/page-02.png")
    }

    func testDoublePageSpreadSetsCenterPage() async throws {
        let publication = try await parser.parse(asset: cbzWithComicInfoAsset, warnings: nil).get().build()

        XCTAssertNil(publication.readingOrder[0].properties.page)
        XCTAssertNil(publication.readingOrder[1].properties.page)

        // Page 2 has DoublePage="True" in ComicInfo.xml, should have center page
        XCTAssertEqual(publication.readingOrder[2].properties.page, .center)
    }
}
