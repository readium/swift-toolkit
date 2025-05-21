//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class EPUBDeobfuscatorTests: XCTestCase {
    let fixtures = Fixtures(path: "EPUBDeobfuscator")

    var font: Data!

    override func setUpWithError() throws {
        font = fixtures.data(at: "cut-cut.woff")
    }

    func testDeobfuscateIDPF() async throws {
        let sut = try sut(resourcePath: "cut-cut.obf.woff", algorithm: "http://www.idpf.org/2008/embedding")
        let result = await sut.deobfuscate()
        XCTAssertEqual(result, .success(font))
    }

    func testDeobfuscateAdobe() async throws {
        let sut = try sut(resourcePath: "cut-cut.adb.woff", algorithm: "http://ns.adobe.com/pdf/enc#RC")
        let result = await sut.deobfuscate()
        XCTAssertEqual(result, .success(font))
    }

    // Fix for https://github.com/readium/r2-streamer-swift/issues/208
    func testEmptyPublicationID() async throws {
        let file = fixtures.data(at: "nav.xhtml")

        var sut = try sut(publicationID: "urn:uuid:", resourcePath: "nav.xhtml", algorithm: "http://www.idpf.org/2008/embedding")
        var result = await sut.deobfuscate()
        XCTAssertEqual(result, .success(file))

        sut = try self.sut(publicationID: "", resourcePath: "nav.xhtml", algorithm: "http://www.idpf.org/2008/embedding")
        result = await sut.deobfuscate()
        XCTAssertEqual(result, .success(file))
    }

    private func sut(
        publicationID: String = "urn:uuid:36d5078e-ff7d-468e-a5f3-f47c14b91f2f",
        resourcePath path: String,
        algorithm: String
    ) throws -> (
        deobfuscate: () async -> ReadResult<Data>,
        resource: DataResource,
        encryptions: [RelativeURL: Encryption]
    ) {
        let url = try XCTUnwrap(RelativeURL(path: path))
        let data = fixtures.data(at: path)
        let resource = DataResource(data: data)
        let encryptions = [url: Encryption(algorithm: algorithm)]
        let deobfuscator = EPUBDeobfuscator(
            publicationId: publicationID,
            encryptions: encryptions
        )
        return (
            deobfuscate: {
                await deobfuscator.deobfuscate(resource: resource, at: url.anyURL).read()
            },
            resource: resource,
            encryptions: [url: Encryption(algorithm: algorithm)]
        )
    }
}
