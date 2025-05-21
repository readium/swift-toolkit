//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class ReadiumWebPubParserTests: XCTestCase {
    let fixtures = Fixtures()
    var parser: ReadiumWebPubParser!

    var manifestAsset: Asset!
    var packageAsset: Asset!
    var lcpdfAsset: Asset!

    override func setUp() async throws {
        parser = ReadiumWebPubParser(pdfFactory: DefaultPDFDocumentFactory(), httpClient: DefaultHTTPClient())

        manifestAsset = .resource(ResourceAsset(
            resource: FileResource(file: fixtures.url(for: "flatland.json")),
            format: Format(specifications: .json, .rwpm, mediaType: .readiumWebPubManifest, fileExtension: "json")
        ))

        packageAsset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "audiotest.lcpa")),
            format: Format(specifications: .zip, .rpf, .lcp, mediaType: .lcpProtectedAudiobook, fileExtension: "lcpa")
        ).get())

        lcpdfAsset = try await .container(ZIPArchiveOpener().open(
            resource: FileResource(file: fixtures.url(for: "daisy.lcpdf")),
            format: Format(specifications: .zip, .rpf, .lcp, mediaType: .lcpProtectedPDF, fileExtension: "lcpdf")
        ).get())
    }

    func testRefusesNonReadiumWebPub() async throws {
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

    func testAcceptsManifest() async throws {
        let result = try await parser.parse(asset: manifestAsset, warnings: nil).get()
        XCTAssertNotNil(result)
    }

    func testAcceptsPackage() async throws {
        let result = try await parser.parse(asset: packageAsset, warnings: nil).get()
        XCTAssertNotNil(result)
    }
}
