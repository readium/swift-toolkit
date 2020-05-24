//
//  EPUBEncryptionParserTests.swift
//  R2StreamerTests
//
//  Created by Mickaël Menu on 21.05.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
import R2Shared
@testable import R2Streamer


class EPUBEncryptionParserTests: XCTestCase {
    
    func testParseLCPEncryption() {
        let sut = parseEncryptions("encryption-lcp", drm: DRM(brand: .lcp))

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
        let sut = parseEncryptions("encryption-lcp-namespaces", drm: DRM(brand: .lcp))

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
    
    func parseEncryptions(_ name: String, drm: DRM? = nil) -> [String: Encryption] {
        let url = SampleGenerator().getSamplesFileURL(named: "Encryption/\(name)", ofType: "xml")!
        let data = try! Data(contentsOf: url)
        return EPUBEncryptionParser(container: FileContainer(path: "", mimetype: ""), data: data, drm: drm).parseEncryptions()
    }
    
}
