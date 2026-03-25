//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import XCTest

func AssertImageEqual(_ image1: UIImage?, _ image2: UIImage?, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(image1?.pngData(), image2?.pngData(), file: file, line: line)
}

func AssertImageEqual<F: Error>(_ image1: Result<UIImage?, F>, _ image2: Result<UIImage?, F>, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(try image1.get()?.pngData(), try image2.get()?.pngData(), file: file, line: line)
}
