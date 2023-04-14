//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
@testable import R2Streamer
import XCTest

class PublicationParsingTests: XCTestCase, Loggable {
    let fixtures = Fixtures()
    let streamer = Streamer()

    func testParseCbz() {
        parse(url: fixtures.url(for: "futuristic_tales.cbz"))
    }

    func testParseCbzDirectory() {
        parse(url: fixtures.url(for: "futuristic_tales"))
    }

    private func parse(url: URL) {
        let expect = expectation(description: "Publication parsed")

        streamer.open(asset: FileAsset(url: url), allowUserInteraction: false) { result in
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
