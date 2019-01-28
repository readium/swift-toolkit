//
//  Created by Mickaël Menu on 28.01.19.
//  Copyright © 2019 Readium. All rights reserved.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class MultilangStringTests: XCTestCase {
    
    // JSONEncoder doesn't allow fragments, so we wrap the SUT in an array before encoding to JSON, because MultilangString is not a full-fledge JSON object.

    func testEmptyJSONSerialization() {
        let sut = MultilangString()
        
        XCTAssertEqual(toJSON([sut]), """
            [""]
            """)
    }
    
    func testNonLocalizedJSONSerialization() {
        let sut = MultilangString()
        sut.singleString = "apple"
        
        XCTAssertEqual(toJSON([sut]), """
            ["apple"]
            """)
    }
    
    func testLocalizedJSONSerialization() {
        let sut = MultilangString()
        sut.singleString = "apple"
        sut.multiString = [
            "fr": "pomme",
            "de": "Apfel"
        ]
        
        XCTAssertEqual(toJSON([sut]), """
            [{"de":"Apfel","fr":"pomme"}]
            """)
    }

}
