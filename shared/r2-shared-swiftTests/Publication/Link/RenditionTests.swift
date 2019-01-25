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

class RenditionTests: XCTestCase {
    
    func toJSON(_ publication: Rendition) -> String? {
        return Mapper().toJSONString(publication)
    }
    
    func testEmptyJSONSerialization() {
        let sut = Rendition()
        
        XCTAssertEqual(toJSON(sut), """
            {}
            """)
    }
    
    func testJSONSerialization() {
        let sut = Rendition()
        sut.layout = .reflowable
        sut.flow = .paginated
        sut.orientation = .landscape
        sut.spread = .auto
        sut.viewport = "1280x720"

        XCTAssertEqual(toJSON(sut), """
            {"viewport":"1280x720","layout":"reflowable","flow":"paginated","spread":"auto","orientation":"landscape"}
            """)
    }
    
}
