//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
import R2Shared
@testable import R2Streamer

class PublicationParsingTests: XCTestCase, Loggable {
    
    let fixtures = Fixtures()
    let streamer = Streamer()

    /// Try to parse the .epub samples.
    func testParseEpub() {
        parse(url: fixtures.url(for: "cc-shared-culture.epub"))
        parse(url: fixtures.url(for: "SmokeTestFXL.epub"))
    }

    /// Attemp to parse the Epub directories samples.
    func testParseEpubDirectory() {
        parse(url: fixtures.url(for: "cc-shared-culture"))
        parse(url: fixtures.url(for: "SmokeTestFXL"))
    }

    func testParseCbz() {
        parse(url: fixtures.url(for: "futuristic_tales.cbz"))
    }

    func testParseCbzDirectory() {
        parse(url: fixtures.url(for: "futuristic_tales"))
    }
    
    private func parse(url: URL) {
        let expect = expectation(description: "Publication parsed")
    
        streamer.open(file: File(url: url), allowUserInteraction: false) { result in
            switch result {
            case .success:
                expect.fulfill()
            case .failure:
                XCTFail("Failed to parse \(url)")
            case .cancelled:
                XCTFail("Parsing of \(url) cancelled")
            }
        }
    
        waitForExpectations(timeout: 2, handler: nil)
    }
    
}
