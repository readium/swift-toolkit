//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest

func AssertJSONEqual(_ json1: Any?, _ json2: Any?, file: StaticString = #file, line: UInt = #line) {
    guard let j1 = json1, let j2 = json2 else {
        if json1 != nil || json2 != nil {
            XCTFail("JSONs are not equal")
        }
        return
    }

    do {
        // Wrap the objects in an array to allow JSON fragments comparisons
        let d1 = try String(data: JSONSerialization.data(withJSONObject: [j1], options: .sortedKeys), encoding: .utf8)
        let d2 = try String(data: JSONSerialization.data(withJSONObject: [j2], options: .sortedKeys), encoding: .utf8)
        XCTAssertEqual(d1, d2, file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription)
    }
}
