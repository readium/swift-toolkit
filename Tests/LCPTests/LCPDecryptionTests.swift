//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PDFKit
@testable import ReadiumLCP
import ReadiumShared
import ReadiumStreamer
import Testing
import TestPublications

struct LCPDecryptionTests {
    let encryptedResource: Resource
    let clearData: Data

    init() async throws {
        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)

        let service = LCPService(
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

        let encryptedURL = TestPublications.url(for: "daisy.lcpdf")
        let asset = try await assetRetriever.retrieve(url: encryptedURL.anyURL.absoluteURL!).get()
        let publication = try await pubOpener.open(asset: asset, allowUserInteraction: false).get()

        encryptedResource = publication.get(publication.readingOrder.first!)!
        clearData = try Data(contentsOf: TestPublications.url(for: "daisy.pdf"))
    }

    @Test func decryptFull() async throws {
        let result = try await encryptedResource.read().get()
        #expect(result == clearData)
    }

    @Test func decryptsVariousRanges() async throws {
        // These ranges seem arbitrary, but some of them were failing before the
        // fix in the same commit.
        let ranges: [Range<UInt64>] = [
            0 ..< 2048,
            817_152 ..< 819_200,
            819_200 ..< 819_856,
            0 ..< 16384,
            819_792 ..< 819_856,
            819_565 ..< 819_856,
        ]

        for range in ranges {
            let intRange = Int(range.lowerBound) ..< Int(range.upperBound)
            let decrypted = try await encryptedResource.read(range: range).get()
            #expect(decrypted == clearData[intRange], "Failed to decrypt range \(intRange)")
        }
    }

    /// Reproduces the arithmetic overflow in
    /// `CBCLCPResource.stream(range:consume:)`.
    ///
    /// When a range's last byte falls in the overflow zone
    /// (≥ encryptedLength − 16), `encryptedEndExclusive` exceeds
    /// `encryptedLength`. The subsequent subtraction
    /// `encryptedLength − encryptedEndExclusive` underflows UInt64 and
    /// crashes.
    ///
    /// For daisy.pdf (819 856 bytes, a multiple of 16) PKCS7 adds a full
    /// padding block, so encryptedLength = 819 856 + 16 + 16 = 819 888.
    /// The range below puts
    /// `rangeLast = clearData.count + 16 = 819 872 = encryptedLength − 16`,
    /// the minimum value that triggers the overflow.
    /// The fix clamps `encryptedEndExclusive` to `encryptedLength` before
    /// the subtraction.
    @Test func encryptedEndExclusiveOverflow() async throws {
        // Starts 16 bytes before the end of the valid plaintext, ends 17
        // bytes past it.
        let start = UInt64(clearData.count - 16)
        let end = UInt64(clearData.count + 17)

        let result = try await encryptedResource.read(range: start ..< end).get()

        // Only the bytes within the plaintext boundary should be returned.
        #expect(result == clearData[(clearData.count - 16)...])
    }
}
