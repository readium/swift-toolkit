//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
@testable import R2Streamer
import XCTest

class EPUBEncryptionParserTests: XCTestCase {
    let fixtures = Fixtures(path: "Encryption")

    func testParseLCPEncryption() {
        let sut = parseEncryptions("encryption-lcp")

        XCTAssertEqual(sut, [
            "/chapter01.xhtml": Encryption(
                algorithm: "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
                compression: "deflate",
                originalLength: 13291,
                profile: nil,
                scheme: "http://readium.org/2014/01/lcp"
            ),
            "/dir/chapter02.xhtml": Encryption(
                algorithm: "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
                compression: "none",
                originalLength: 12914,
                profile: nil,
                scheme: "http://readium.org/2014/01/lcp"
            ),
        ])
    }

    func testParseEncryptionWithNamespaces() {
        let sut = parseEncryptions("encryption-lcp-namespaces")

        XCTAssertEqual(sut, [
            "/chapter01.xhtml": Encryption(
                algorithm: "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
                compression: "deflate",
                originalLength: 13291,
                profile: nil,
                scheme: "http://readium.org/2014/01/lcp"
            ),
            "/dir/chapter02.xhtml": Encryption(
                algorithm: "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
                compression: "none",
                originalLength: 12914,
                profile: nil,
                scheme: "http://readium.org/2014/01/lcp"
            ),
        ])
    }

    func testParseEncryptionForUnknownDRM() {
        let sut = parseEncryptions("encryption-unknown-drm")

        XCTAssertEqual(sut, [
            "/html/chapter.html": Encryption(
                algorithm: "http://www.w3.org/2001/04/xmlenc#kw-aes128",
                compression: "deflate",
                originalLength: 12914,
                profile: nil,
                scheme: nil
            ),
            "/images/image.jpeg": Encryption(
                algorithm: "http://www.w3.org/2001/04/xmlenc#kw-aes128",
                compression: nil,
                originalLength: nil,
                profile: nil,
                scheme: nil
            ),
        ])
    }

    // MARK: - Toolkit

    func parseEncryptions(_ name: String) -> [String: Encryption] {
        let data = fixtures.data(at: "\(name).xml")
        return EPUBEncryptionParser(fetcher: EmptyFetcher(), data: data).parseEncryptions()
    }
}
