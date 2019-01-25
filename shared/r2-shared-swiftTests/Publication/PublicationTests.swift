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

class PublicationTests: XCTestCase {
    
    func toJSON(_ publication: Publication) -> String? {
        return Mapper().toJSONString(publication)
    }

    func testEmptyJSONSerialization() {
        let sut = Publication()
        
        XCTAssertEqual(toJSON(sut), """
            {"metadata":{"languages":[],"title":"","subtitle":""}}
            """)
    }
    
    func testJSONSerialization() {
        func multilangString(_ title: String) -> MultilangString {
            let string = MultilangString()
            string.singleString = title
            return string
        }

        func link(_ title: String) -> Link {
            let link = Link()
            link.title = title
            return link
        }
        
        func userProperties(_ props: [UserProperty]) -> UserProperties {
            let userProperties = UserProperties()
            userProperties.properties = props
            return userProperties
        }

        let sut = Publication()
        sut.version = 1.2
        sut.metadata = Metadata()
        sut.metadata.multilangTitle = multilangString("Title")
        sut.links = [link("link1"), link("link2")]
        sut.spine = [link("spine")]
        sut.resources = [link("resource")]
        sut.tableOfContents = [link("toc")]
        sut.landmarks = [link("landmark")]
        sut.listOfAudioFiles = [link("audio")]
        sut.listOfIllustrations = [link("illustration")]
        sut.listOfTables = [link("table")]
        sut.listOfVideos = [link("video")]
        sut.pageList = [link("page")]
        sut.images = [link("image")]
        sut.userProperties = userProperties([UserProperty("ref", "name")])
        sut.updatedDate = Date(timeIntervalSinceReferenceDate: 8374)
        sut.otherLinks = [link("otherlink")]
        sut.internalData = ["data1": "value1"]
        sut.userSettingsUIPreset = [.fontSize: true]

        XCTAssertEqual(toJSON(sut), """
            {"metadata":{"languages":[],"title":"Title","subtitle":"Title"},"page-list":[{"title":"page"}],"loi":[{"title":"illustration"}],"lot":[{"title":"table"}],"landmarks":[{"title":"landmark"}],"spine":[{"title":"spine"}],"links":[{"title":"link1"},{"title":"link2"}],"resources":[{"title":"resource"}],"toc":[{"title":"toc"}]}
            """)
    }

}
