//
//  readium_odps1_1_searchHelper_test.swift
//  readium-opdsTests
//
//  Created by Nikita Aizikovskyi on Jan-29-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import XCTest
import PromiseKit
import AEXML
import R2Shared
@testable import ReadiumOPDS


class readium_odps1_1_searchHelper_test: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let testBundle = Bundle(for: type(of: self))
        guard let fileURL = testBundle.url(forResource: "feedbooks_catalog", withExtension: "atom") else {
            XCTFail("Unable to locate test file")
            return
        }

        guard let opdsData = try? Data(contentsOf: fileURL) else {
            XCTFail("Unable to load test file")
            return
        }

        guard let feed = try? OPDSParser.parse(xmlData: opdsData) else {
            XCTFail("Unable to parse the sample feed")
            return
        }

        var template: String? = nil
        let expectation = XCTestExpectation()

        firstly {
            OPDSParser.fetchOpenSearchTemplate(feed: feed)
        }.then { templateResult -> Void in
            template = templateResult
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        XCTAssert(template == "http://www.feedbooks.com/search.atom?query={searchTerms}")

    }
}
