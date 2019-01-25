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

class SubjectTests: XCTestCase {
    
    func toJSON(_ publication: Subject) -> String? {
        return Mapper().toJSONString(publication)
    }

    func testEmptyJSONSerialization() {
        let sut = Subject()

        XCTAssertEqual(toJSON(sut), """
            {}
            """)
    }
    
    func testJSONSerialization() {
        func link(_ title: String) -> Link {
            let link = Link()
            link.title = title
            return link
        }
        
        
        let sut = Subject()
        sut.name = "Name"
        sut.sortAs = "sorting"
        sut.scheme = "a-scheme"
        sut.code = "a-code"
        sut.links = [link("link1"), link("link2")]

        XCTAssertEqual(toJSON(sut), """
            {"name":"Name","scheme":"a-scheme","sortAs":"sorting","code":"a-code"}
            """)
    }

}
