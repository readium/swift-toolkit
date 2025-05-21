//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumInternal
import XCTest

class URLTests: XCTestCase {
    func testAddingSchemeWhenMissing() {
        XCTAssertEqual(
            URL(string: "//www.google.com/path")!.addingSchemeWhenMissing("test"),
            URL(string: "test://www.google.com/path")!
        )
        XCTAssertEqual(
            URL(string: "http://www.google.com/path")!.addingSchemeWhenMissing("test"),
            URL(string: "http://www.google.com/path")!
        )
    }
}
