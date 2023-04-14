//
//  Asserts.swift
//  r2-streamer-swift
//
//  Created by Mickaël on 26/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
        let d1 = String(data: try JSONSerialization.data(withJSONObject: [j1], options: .sortedKeys), encoding: .utf8)
        let d2 = String(data: try JSONSerialization.data(withJSONObject: [j2], options: .sortedKeys), encoding: .utf8)
        XCTAssertEqual(d1, d2, file: file, line: line)
    } catch {
        XCTFail(error.localizedDescription)
    }
}
