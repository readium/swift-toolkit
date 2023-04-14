//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Navigator
import R2Shared
import XCTest

class CSSLayoutTests: XCTestCase {
    func testComputeHTMLDiStylesheets() {
        XCTAssertEqual(CSSLayout.Stylesheets.default.htmlDir, .ltr)
        XCTAssertEqual(CSSLayout.Stylesheets.rtl.htmlDir, .rtl)
        XCTAssertEqual(CSSLayout.Stylesheets.cjkVertical.htmlDir, .unspecified)
        XCTAssertEqual(CSSLayout.Stylesheets.cjkHorizontal.htmlDir, .ltr)
    }
}
