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

class PublicationTests: XCTestCase {

    func testEmptyJSONSerialization() {
        let sut = Publication()
        
        XCTAssertEqual(toJSON(sut), """
            {"metadata":{"languages":[],"title":""}}
            """)
    }
    
    func testJSONSerialization() {
        let sut = publication()

        XCTAssertEqual(toJSON(sut), """
            {"landmarks":[{"title":"landmark"}],"links":[{"title":"link1"},{"title":"link2"}],"loi":[{"title":"illustration"}],"lot":[{"title":"table"}],"metadata":{"languages":[],"title":"Title"},"page-list":[{"title":"page"}],"resources":[{"title":"resource"}],"spine":[{"title":"spine"}],"toc":[{"title":"toc"}]}
            """)
    }
    
    func testManifest() {
        let sut = publication()
        // To check that slashes are not escaped
        sut.links.append(link("link-url", href: "http://link.com"))
        
        XCTAssertEqual(sut.manifest, """
            {
              "loi" : [
                {
                  "title" : "illustration"
                }
              ],
              "resources" : [
                {
                  "title" : "resource"
                }
              ],
              "landmarks" : [
                {
                  "title" : "landmark"
                }
              ],
              "spine" : [
                {
                  "title" : "spine"
                }
              ],
              "links" : [
                {
                  "title" : "link1"
                },
                {
                  "title" : "link2"
                },
                {
                  "title" : "link-url",
                  "href" : "http://link.com"
                }
              ],
              "lot" : [
                {
                  "title" : "table"
                }
              ],
              "page-list" : [
                {
                  "title" : "page"
                }
              ],
              "metadata" : {
                "title" : "Title",
                "languages" : [

                ]
              },
              "toc" : [
                {
                  "title" : "toc"
                }
              ]
            }
            """)
    }
    
    
    func testManifestCanonical() {
        let sut = publication()
        // To check that slashes are not escaped
        sut.landmarks.append(link("landmark", href: "http://link.com"))
        // To check that links are removed
        sut.links.append(link("link", href: "http://link.com"))
        
        XCTAssertEqual(sut.manifestCanonical, """
            {"landmarks":[{"title":"landmark"},{"href":"http://link.com","title":"landmark"}],"loi":[{"title":"illustration"}],"lot":[{"title":"table"}],"metadata":{"languages":[],"title":"Title"},"page-list":[{"title":"page"}],"resources":[{"title":"resource"}],"spine":[{"title":"spine"}],"toc":[{"title":"toc"}]}
            """)
    }
    
    func testManifestDictionary() {
        let sut = publication()
        
        let json = String(data: try! JSONSerialization.data(withJSONObject: sut.manifestDictionnary, options: [.sortedKeys]), encoding: .utf8)!
        XCTAssertEqual(json, """
            {"landmarks":[{"title":"landmark"}],"links":[{"title":"link1"},{"title":"link2"}],"loi":[{"title":"illustration"}],"lot":[{"title":"table"}],"metadata":{"languages":[],"title":"Title"},"page-list":[{"title":"page"}],"resources":[{"title":"resource"}],"spine":[{"title":"spine"}],"toc":[{"title":"toc"}]}
            """)
    }
    
    func publication() -> Publication {
        let publication = Publication()
        publication.version = 1.2
        publication.metadata = Metadata()
        publication.metadata.multilangTitle = multilangString("Title")
        publication.links = [link("link1"), link("link2")]
        publication.readingOrder = [link("spine")]
        publication.resources = [link("resource")]
        publication.tableOfContents = [link("toc")]
        publication.landmarks = [link("landmark")]
        publication.listOfAudioFiles = [link("audio")]
        publication.listOfIllustrations = [link("illustration")]
        publication.listOfTables = [link("table")]
        publication.listOfVideos = [link("video")]
        publication.pageList = [link("page")]
        publication.images = [link("image")]
        publication.userProperties = userProperties([UserProperty("ref", "name")])
        publication.updatedDate = Date(timeIntervalSinceReferenceDate: 8374)
        publication.otherLinks = [link("otherlink")]
        publication.internalData = ["data1": "value1"]
        publication.userSettingsUIPreset = [.fontSize: true]
        return publication
    }
    
    func multilangString(_ title: String) -> MultilangString {
        let string = MultilangString()
        string.singleString = title
        return string
    }
    
    func link(_ title: String, href: String? = nil) -> Link {
        let link = Link()
        link.title = title
        link.href = href
        return link
    }
    
    func userProperties(_ props: [UserProperty]) -> UserProperties {
        let userProperties = UserProperties()
        userProperties.properties = props
        return userProperties
    }
    
}
