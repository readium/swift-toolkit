//
//  Asserts.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest

func AssertJSONEqual(_ json1: Any, _ json2: Any, file: StaticString = #file, line: UInt = #line) {
    do {
        // Wrap the objects in an array to allow JSON fragments comparisons
        let d1 = String(data: try JSONSerialization.data(withJSONObject: [json1], options: .sortedKeys), encoding: .utf8)
        let d2 = String(data: try JSONSerialization.data(withJSONObject: [json2], options: .sortedKeys), encoding: .utf8)
        XCTAssertEqual(d1, d2, file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription)
    }
}

func AssertImageEqual(_ image1: UIImage?, _ image2: UIImage?, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(image1?.pngData(), image2?.pngData(), file: file, line: line)
}
