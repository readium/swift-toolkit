//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import XCTest

class CSSLayoutTests: XCTestCase {
    func testComputeHTMLDiStylesheets() {
        XCTAssertEqual(CSSLayout.Stylesheets.default.htmlDir, .ltr)
        XCTAssertEqual(CSSLayout.Stylesheets.rtl.htmlDir, .rtl)
        XCTAssertEqual(CSSLayout.Stylesheets.cjkVertical.htmlDir, .unspecified)
        XCTAssertEqual(CSSLayout.Stylesheets.cjkHorizontal.htmlDir, .ltr)
    }
}
