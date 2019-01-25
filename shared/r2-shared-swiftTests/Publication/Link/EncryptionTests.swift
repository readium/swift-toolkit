//
//  Created by Mickaël Menu on 25.01.19.
//  Copyright © 2019 Readium. All rights reserved.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import ObjectMapper
import XCTest
@testable import R2Shared

class EncryptionTests: XCTestCase {
    
    func toJSON(_ publication: Encryption) -> String? {
        return Mapper().toJSONString(publication)
    }
    
    func testEmptyJSONSerialization() {
        let sut = Encryption()
        
        XCTAssertEqual(toJSON(sut), """
            {}
            """)
    }
    
    func testJSONSerialization() {
        var sut = Encryption()
        sut.algorithm = "http://algorithm"
        sut.compression = "gzip"
        sut.originalLength = 12030
        sut.profile = "http://profile"
        sut.scheme = "http://scheme"

        XCTAssertEqual(toJSON(sut), """
            {"profile":"http:\\/\\/profile","scheme":"http:\\/\\/scheme","compression":"gzip","algorithm":"http:\\/\\/algorithm","originalLength":12030}
            """)
    }
    
}
