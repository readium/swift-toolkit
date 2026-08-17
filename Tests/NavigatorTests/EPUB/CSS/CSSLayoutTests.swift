//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct CSSLayoutTests {
    @Test func computeHTMLDiStylesheets() {
        #expect(CSSLayout.Stylesheets.default.htmlDir == .ltr)
        #expect(CSSLayout.Stylesheets.rtl.htmlDir == .rtl)
        #expect(CSSLayout.Stylesheets.cjkVertical.htmlDir == .unspecified)
        #expect(CSSLayout.Stylesheets.cjkHorizontal.htmlDir == .ltr)
    }
}
