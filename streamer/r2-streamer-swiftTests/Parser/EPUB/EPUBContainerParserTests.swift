//
//  EPUBContainerParserTests.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 03.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
import Fuzi
import R2Shared
@testable import R2Streamer


class EPUBContainerParserTests: XCTestCase {

    func testParseRootFilePath() throws {
        let url = SampleGenerator().getSamplesFileURL(named: "Container/container", ofType: "xml")!
        let data = try Data(contentsOf: url)
        let parser = try EPUBContainerParser(data: data)
        
        XCTAssertEqual(try parser.parseRootFilePath(), "EPUB/content.opf")
    }

}
