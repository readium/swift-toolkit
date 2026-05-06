//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PDFKit
@testable import ReadiumLCP
import ReadiumShared
import ReadiumStreamer
import TestPublications
import XCTest

class LCPDecryptionTests: XCTestCase {
    var service: LCPService!
    var encryptedResource: Resource!
    var clearData: Data!

    override func setUp() async throws {
        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)

        service = LCPService(
            client: LCPTestClient(),
            licenseRepository: InMemoryLCPLicenseRepository(),
            passphraseRepository: InMemoryLCPPassphraseRepository(),
            assetRetriever: assetRetriever,
            httpClient: httpClient
        )

        let pubOpener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            ),
            contentProtections: [
                service.contentProtection(with: LCPPassphraseAuthentication("test")),
            ]
        )

        let unencryptedURL = TestPublications.url(for: "daisy.pdf")
        let encryptedURL = TestPublications.url(for: "daisy.lcpdf")

        let asset = try await assetRetriever.retrieve(url: encryptedURL.anyURL.absoluteURL!).get()
        let publication = try await pubOpener.open(asset: asset, allowUserInteraction: false).get()
        XCTAssertFalse(publication.isRestricted)

        encryptedResource = publication.get(publication.readingOrder.first!)

        clearData = try Data(contentsOf: unencryptedURL)
    }

    /// Checks that we can decrypt the full content successfully.
    func testDecryptFull() async throws {
        let result = try await encryptedResource.read().get()
        XCTAssertEqual(result, clearData)
    }

    /// Checks that we can decrypt various ranges successfully.
    func testDecryptRanges() async throws {
        // These ranges seem arbirtrary, but some of them were failing before the fix in the
        // same commit.
        let ranges: [Range<UInt64>] = [
            0 ..< 2048, // 2048
            817_152 ..< 819_200, // 2048
            819_200 ..< 819_856, // 656
            0 ..< 16384, // 16384
            819_792 ..< 819_856, // 64
            819_565 ..< 819_856, // 291
        ]

        for range in ranges {
            let intRange = Int(range.lowerBound) ..< Int(range.upperBound)
            let decrypted = try await encryptedResource.read(range: range).get()
            let clear = clearData[intRange]
            XCTAssertEqual(decrypted, clear, "Failed to decrypt range \(intRange)")
        }
    }
}
