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
        parse(file: fixtures.url(for: "futuristic_tales.cbz"))
    }

    func testParseCbzDirectory() {
        parse(file: fixtures.url(for: "futuristic_tales"))
    }

    private func parse(file: FileURL) {
        let expect = expectation(description: "Publication parsed")

        streamer.open(asset: FileAsset(file: file), allowUserInteraction: false) { result in
            switch result {
            case .success:
                expect.fulfill()
            case .failure:
                XCTFail("Failed to parse \(file)")
            case .cancelled:
                XCTFail("Parsing of \(file) cancelled")
            }
        }

        waitForExpectations(timeout: 2, handler: nil)
    }
}
