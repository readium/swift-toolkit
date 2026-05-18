//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest

func AssertImageEqual(_ image1: UIImage?, _ image2: UIImage?, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(image1?.pngData(), image2?.pngData(), file: file, line: line)
}
