//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import PDFKit
@testable import ReadiumLCP
import ReadiumShared
import XCTest

class LCPDecryptorTests: XCTestCase {
    let fixtures = Fixtures()
    var service: LCPService!
    var encryptedResource: Resource!
    var clearData: Data!

    override func setUpWithError() throws {
        service = LCPService(client: LCPTestClient())

        let fetcher = try ArchiveFetcher(archive: DefaultArchiveFactory().open(url: fixtures.url(for: "daisy.lcpdf"), password: nil))
        encryptedResource = fetcher.get(Link(
            href: "/publication.pdf",
            properties: Properties([
                "encrypted": [
                    "scheme": "http://readium.org/2014/01/lcp",
                    "profile": "http://readium.org/lcp/basic-profile",
                    "algorithm": "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
                ],
            ])
        ))

        clearData = try Data(contentsOf: fixtures.url(for: "daisy.pdf"))
    }

    /// Checks that we can decrypt the full content successfully.
    func testDecryptFull() throws {
        retrieveLicense(path: "daisy.lcpdf", passphrase: "test") { license in
            let decryptedResource = LCPDecryptor(license: license).decrypt(resource: self.encryptedResource)

            XCTAssertEqual(try decryptedResource.read().get(), self.clearData)
        }
    }

    /// Checks that we can decrypt various ranges successfully.
    func testDecryptRanges() throws {
        retrieveLicense(path: "daisy.lcpdf", passphrase: "test") { license in
            let decryptedResource = LCPDecryptor(license: license).decrypt(resource: self.encryptedResource)

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
                let decrypted = try decryptedResource.read(range: range).get()
                let clear = self.clearData[intRange]
                XCTAssertEqual(decrypted, clear, "Failed to decrypt range \(intRange)")
            }
        }
    }

    private func retrieveLicense(path: String, passphrase: String, completion: @escaping (LCPLicense) throws -> Void) {
        let completionExpectation = expectation(description: "License opened")

        let url = fixtures.url(for: path)
        service.retrieveLicense(from: url, authentication: LCPPassphraseAuthentication(passphrase), allowUserInteraction: false) { result in
            try! completion((try! result.get())!)
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: 30, handler: nil)
    }
}
