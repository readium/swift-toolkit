//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

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
        parser = ReadiumWebPubParser(pdfFactory: DefaultPDFDocumentFactory(), httpClient: DefaultHTTPClient())

        manifestAsset = FileAsset(file: fixtures.url(for: "flatland.json"))
        manifestFetcher = FileFetcher(href: RelativeURL(path: "flatland.json")!, file: manifestAsset.file)

        packageAsset = FileAsset(file: fixtures.url(for: "audiotest.lcpa"))
        packageFetcher = try ArchiveFetcher(file: packageAsset.file)

        lcpdfAsset = FileAsset(file: fixtures.url(for: "daisy.lcpdf"))
        lcpdfFetcher = try ArchiveFetcher(file: lcpdfAsset.file)
    }

    func testRefusesNonReadiumWebPub() throws {
        let asset = FileAsset(file: fixtures.url(for: "audiotest.zab"))
        let fetcher = try ArchiveFetcher(file: asset.file)
        XCTAssertNil(try parser.parse(asset: asset, fetcher: fetcher, warnings: nil))
    }

    func testAcceptsManifest() {
        XCTAssertNotNil(try parser.parse(asset: manifestAsset, fetcher: manifestFetcher, warnings: nil))
    }

    func testAcceptsPackage() {
        XCTAssertNotNil(try parser.parse(asset: packageAsset, fetcher: packageFetcher, warnings: nil))
    }
}
