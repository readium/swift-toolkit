//
//  Publication+EPUBTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 14.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class PublicationEPUBTests: XCTestCase {
    
    var sut: Publication!
    
    override func setUp() {
        sut = Publication(metadata: Metadata(title: ""), links: [], readingOrder: [])
    }

    func testNoPageList() {
        XCTAssertEqual(sut.pageList, [])
    }

    func testPageList() {
        sut.otherCollections.append(
            PublicationCollection(role: "pageList", links: [Link(href: "/page1.html")])
        )
        
        XCTAssertEqual(
            sut.pageList,
            [Link(href: "/page1.html")]
        )
    }

    func testNoLandmarks() {
        XCTAssertEqual(sut.landmarks, [])
    }
    
    func testLandmarks() {
        sut.otherCollections.append(
            PublicationCollection(role: "landmarks", links: [Link(href: "/landmark.html")])
        )
        
        XCTAssertEqual(
            sut.landmarks,
            [Link(href: "/landmark.html")]
        )
    }

    func testNoListOfAudioClips() {
        XCTAssertEqual(sut.listOfAudioClips, [])
    }
    
    func testListOfAudioClips() {
        sut.otherCollections.append(
            PublicationCollection(role: "loa", links: [Link(href: "/audio.mp3")])
        )
        
        XCTAssertEqual(
            sut.listOfAudioClips,
            [Link(href: "/audio.mp3")]
        )
    }

    func testNoListOfIllustrations() {
        XCTAssertEqual(sut.listOfIllustrations, [])
    }
    
    func testListOfIllustrations() {
        sut.otherCollections.append(
            PublicationCollection(role: "loi", links: [Link(href: "/image.jpg")])
        )
        
        XCTAssertEqual(
            sut.listOfIllustrations,
            [Link(href: "/image.jpg")]
        )
    }

    func testNoListOfTables() {
        XCTAssertEqual(sut.listOfTables, [])
    }
    
    func testListOfTables() {
        sut.otherCollections.append(
            PublicationCollection(role: "lot", links: [Link(href: "/table.html")])
        )
        
        XCTAssertEqual(
            sut.listOfTables,
            [Link(href: "/table.html")]
        )
    }

    func testNoListOfVideoClips() {
        XCTAssertEqual(sut.listOfVideoClips, [])
    }
    
    func testListOfVideoClips() {
        sut.otherCollections.append(
            PublicationCollection(role: "lov", links: [Link(href: "/video.mov")])
        )
        
        XCTAssertEqual(
            sut.listOfVideoClips,
            [Link(href: "/video.mov")]
        )
    }

}
