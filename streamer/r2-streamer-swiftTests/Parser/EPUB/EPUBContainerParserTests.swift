//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
import Fuzi
import R2Shared
@testable import R2Streamer


class EPUBContainerParserTests: XCTestCase {
    
    let fixtures = Fixtures(path: "Container")

    func testParseRootFilePath() throws {
        let data = fixtures.data(at: "container.xml")
        let parser = try EPUBContainerParser(data: data)
        
        XCTAssertEqual(try parser.parseOPFHREF(), "/EPUB/content.opf")
    }

}
