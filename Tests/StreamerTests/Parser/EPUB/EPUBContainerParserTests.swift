//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumFuzi
import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class EPUBContainerParserTests: XCTestCase {
    let fixtures = Fixtures(path: "Container")

    func testParseRootFilePath() throws {
        let data = fixtures.data(at: "container.xml")
        let parser = try EPUBContainerParser(data: data)

        XCTAssertEqual(try parser.parseOPFHREF(), RelativeURL(path: "EPUB/content.opf"))
    }
}
