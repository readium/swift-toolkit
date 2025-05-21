//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumInternal
import XCTest

class StringTests: XCTestCase {
    func testSubstringBeforeLast() {
        XCTAssertEqual("href".substringBeforeLast("#"), "href")
        XCTAssertEqual("href#anchor".substringBeforeLast("#"), "href")
        XCTAssertEqual("href#anchor#test".substringBeforeLast("#"), "href#anchor")
    }
}
