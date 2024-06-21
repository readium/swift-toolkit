//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

// FIXME:
class FormatSniffersTests: XCTestCase {
    let fixtures = Fixtures(path: "Format")

    func testSniffIgnoresExtensionCase() {
        // XCTAssertEqual(MediaType.of(fileExtension: "EPUB"), .epub)
    }
}
