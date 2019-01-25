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

class ContributorTests: XCTestCase {
    
    func toJSON(_ publication: Contributor) -> String? {
        return Mapper().toJSONString(publication)
    }
    
    func multilangString(_ title: String?, _ strings: [String: String] = [:]) -> MultilangString {
        let string = MultilangString()
        string.singleString = title
        string.multiString = strings
        return string
    }

    func link(_ title: String) -> Link {
        let link = Link()
        link.title = title
        return link
    }
    
    func testEmptyJSONSerialization() {
        let sut = Contributor()
        
        XCTAssertEqual(toJSON(sut), """
            {"name":""}
            """)
    }
    
    func testJSONSerialization() {
        let sut = Contributor()
        sut.multilangName = multilangString("Name")
        sut.sortAs = "sorting"
        sut.identifier = "identifier"
        sut.roles = ["role1", "role2"]
        sut.links = [link("link1"), link("link2")]

        XCTAssertEqual(toJSON(sut), """
            {"name":"Name","sortAs":"sorting","roles":["role1","role2"],"identifier":"identifier"}
            """)
    }
    
    func testJSONSerializationWithLocalizedName() {
        let sut = Contributor()
        sut.multilangName = multilangString("Michael", ["fr": "Mickaël", "en": "Michael"])

        XCTAssertEqual(toJSON(sut), """
            {"name":{"fr":"Mickaël","en":"Michael"}}
            """)
    }
    
}
