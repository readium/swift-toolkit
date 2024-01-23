//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
@testable import R2Streamer
import XCTest

class EPUBDeobfuscatorTests: XCTestCase {
    let fixtures = Fixtures(path: "EPUBDeobfuscator")

    var deobfuscator: EPUBDeobfuscator!
    var font: Data!

    override func setUpWithError() throws {
        deobfuscator = EPUBDeobfuscator(publicationId: "urn:uuid:36d5078e-ff7d-468e-a5f3-f47c14b91f2f")
        font = fixtures.data(at: "cut-cut.woff")
    }

    func testDeobfuscateIDPF() throws {
        let resource = makeResource(at: "cut-cut.obf.woff", algorithm: "http://www.idpf.org/2008/embedding")

        let result = try deobfuscator.deobfuscate(resource: resource).read().get()
        XCTAssertEqual(result, font)
    }

    func testDeobfuscateAdobe() throws {
        let resource = makeResource(at: "cut-cut.adb.woff", algorithm: "http://ns.adobe.com/pdf/enc#RC")

        let result = try deobfuscator.deobfuscate(resource: resource).read().get()
        XCTAssertEqual(result, font)
    }

    // Fix for https://github.com/readium/r2-streamer-swift/issues/208
    func testEmptyPublicationID() throws {
        let file = fixtures.data(at: "nav.xhtml")
        let resource = makeResource(at: "nav.xhtml", algorithm: "http://www.idpf.org/2008/embedding")

        var deobfuscator = EPUBDeobfuscator(publicationId: "urn:uuid:")
        var result = try deobfuscator.deobfuscate(resource: resource).read().get()
        XCTAssertEqual(result, file)

        deobfuscator = EPUBDeobfuscator(publicationId: "")
        result = try deobfuscator.deobfuscate(resource: resource).read().get()
        XCTAssertEqual(result, file)
    }

    func makeResource(at path: String, algorithm: String) -> DataResource {
        let link = Link(
            href: path,
            properties: Properties([
                "encrypted": [
                    "algorithm": algorithm,
                ],
            ])
        )
        let fixtures = fixtures // capture `fixtures` for the autoclosure
        return DataResource(link: link, data: fixtures.data(at: path))
    }
}
