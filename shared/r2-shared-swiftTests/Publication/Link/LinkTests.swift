//
//  Created by Mickaël Menu on 25.01.19.
//  Copyright © 2019 Readium. All rights reserved.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class LinkTests: XCTestCase {
    
    func testEmptyJSONSerialization() {
        let sut = Link()
        
        XCTAssertEqual(toJSON(sut), """
            {}
            """)
    }
    
    func testJSONSerialization() {
        let sut = Link()
        sut.href = "http://my.link"
        sut.absoluteHref = "http://absolute.com"
        sut.typeLink = "text/html"
        sut.rel = ["rel1", "rel2"]
        sut.height = 100
        sut.width = 200
        sut.title = "Title"
        sut.properties.orientation = "landscape"
        sut.duration = 120
        sut.templated = true
        sut.bitrate = 50
        
        XCTAssertEqual(toJSON(sut), """
            {"duration":120,"height":100,"href":"http:\\/\\/my.link","properties":{"orientation":"landscape"},"rel":["rel1","rel2"],"title":"Title","type":"text\\/html","width":200}
            """)
    }

}
