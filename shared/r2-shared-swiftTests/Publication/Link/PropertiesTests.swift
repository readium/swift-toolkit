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

class PropertiesTests: XCTestCase {
    
    func toJSON(_ publication: Properties) -> String? {
        return Mapper().toJSONString(publication)
    }
    
    func testEmptyJSONSerialization() {
        let sut = Properties()
        
        XCTAssertEqual(toJSON(sut), """
            {}
            """)
    }
    
    func testJSONSerialization() {
        func encryption() -> Encryption {
            var encryption = Encryption()
            encryption.algorithm = "http://algorithm"
            return encryption
        }

        var sut = Properties()
        sut.orientation = "portrait"
        sut.page = "center"
        sut.contains = ["stuff", "thing"]
        sut.mediaOverlay = "http://media-overlay-location.com"
        sut.encryption = encryption()
        sut.layout = "reflowable"
        sut.overflow = "paginated"
        sut.spread = "auto"
        sut.numberOfItems = 3
        sut.price = Price(currency: "EUR", value: 3.29)

        XCTAssertEqual(toJSON(sut), """
            {"encryption":{"algorithm":"http:\\/\\/algorithm"},"page":"center","contains":["stuff","thing"],"spread":"auto","layout":"reflowable","mediaOverlay":"http:\\/\\/media-overlay-location.com","overflow":"paginated","orientation":"portrait"}
            """)
    }
    
}
