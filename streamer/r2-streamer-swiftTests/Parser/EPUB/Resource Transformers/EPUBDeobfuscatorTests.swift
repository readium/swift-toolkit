//
//  EPUBDeobfuscatorTests.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
import R2Shared
@testable import R2Streamer

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

    func makeResource(at path: String, algorithm: String) -> DataResource {
        let link = Link(
            href: path,
            properties: Properties([
                "encrypted": [
                    "algorithm": algorithm
                ]
            ])
        )
        return DataResource(link: link, data: self.fixtures.data(at: path))
    }

}
