//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest

func AssertJSONEqual(_ json1: Any, _ json2: Any, file: StaticString = #file, line: UInt = #line) {
    do {
        // Wrap the objects in an array to allow JSON fragments comparisons
        let d1 = try String(data: JSONSerialization.data(withJSONObject: [json1], options: .sortedKeys), encoding: .utf8)
        let d2 = try String(data: JSONSerialization.data(withJSONObject: [json2], options: .sortedKeys), encoding: .utf8)
        XCTAssertEqual(d1, d2, file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription)
    }
}

func AssertImageEqual(_ image1: UIImage?, _ image2: UIImage?, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(image1?.pngData(), image2?.pngData(), file: file, line: line)
}

func AssertImageEqual<F: Error>(_ image1: Result<UIImage?, F>, _ image2: Result<UIImage?, F>, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(try image1.get()?.pngData(), try image2.get()?.pngData(), file: file, line: line)
}
