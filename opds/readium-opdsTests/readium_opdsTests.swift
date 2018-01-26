//
//  readium_opdsTests.swift
//  readium-opdsTests
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest

import AEXML
@testable import ReadiumOPDS

class readium_opdsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testParseOPDS_1_1() {
        let testBundle = Bundle(for: type(of: self))
        guard let fileURL = testBundle.url(forResource: "wiki_1_1", withExtension: "opds") else {
            XCTFail("Unable to locate test file")
            return
        }

        guard let opdsData = try? Data(contentsOf: fileURL) else {
            XCTFail("Unable to load test file")
            return
        }

        do {
            let feed = try OPDSParser.parse(xmlData: opdsData)
            XCTAssert(feed.metadata.title == "Unpopular Publications")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
