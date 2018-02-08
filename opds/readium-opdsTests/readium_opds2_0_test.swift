//
//  readium_opds2_0_test.swift
//  readium-opdsTests
//
//  Created by Nikita Aizikovskyi on Jan-31-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import XCTest
import R2Shared

@testable import ReadiumOPDS

class readium_opds2_0_test: XCTestCase {

    var feed: Feed?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let testBundle = Bundle(for: type(of: self))
        guard let fileURL = testBundle.url(forResource: "opds_2_0", withExtension: "json") else {
            XCTFail("Unable to locate test file")
            return
        }

        do {
            let opdsData = try Data(contentsOf: fileURL)
            feed = try OPDS2Parser.parse(jsonData: opdsData)
            XCTAssert(feed != nil)
        } catch {
            XCTFail(error.localizedDescription)
        }

        continueAfterFailure = true
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testMetadata() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssert(feed?.metadata.numberOfItem == 5)
    }
}
