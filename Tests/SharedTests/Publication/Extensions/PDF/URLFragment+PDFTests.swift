//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct URLFragmentPDFTests {
    @Test("page(_:) creates a page fragment")
    func page() {
        #expect(URLFragment.page(42).rawValue == "page=42")
    }
}
