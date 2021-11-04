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
    
    func testNoPageList() {
        let sut = makePublication()
        XCTAssertEqual(sut.pageList, [])
    }

    func testPageList() {
        let sut = makePublication(["pageList": [PublicationCollection(links: [Link(href: "/page1.html")])]])

        XCTAssertEqual(
            sut.pageList,
            [Link(href: "/page1.html")]
        )
    }

    func testNoLandmarks() {
        let sut = makePublication()
        XCTAssertEqual(sut.landmarks, [])
    }
    
    func testLandmarks() {
        let sut = makePublication(["landmarks": [PublicationCollection(links: [Link(href: "/landmark.html")])]])
        
        XCTAssertEqual(
            sut.landmarks,
            [Link(href: "/landmark.html")]
        )
    }

    func testNoListOfAudioClips() {
        let sut = makePublication()
        XCTAssertEqual(sut.listOfAudioClips, [])
    }
    
    func testListOfAudioClips() {
        let sut = makePublication(["loa": [PublicationCollection(links: [Link(href: "/audio.mp3")])]])

        XCTAssertEqual(
            sut.listOfAudioClips,
            [Link(href: "/audio.mp3")]
        )
    }

    func testNoListOfIllustrations() {
        let sut = makePublication()
        XCTAssertEqual(sut.listOfIllustrations, [])
    }
    
    func testListOfIllustrations() {
        let sut = makePublication(["loi": [PublicationCollection(links: [Link(href: "/image.jpg")])]])

        XCTAssertEqual(
            sut.listOfIllustrations,
            [Link(href: "/image.jpg")]
        )
    }

    func testNoListOfTables() {
        let sut = makePublication()
        XCTAssertEqual(sut.listOfTables, [])
    }
    
    func testListOfTables() {
        let sut = makePublication(["lot": [PublicationCollection(links: [Link(href: "/table.html")])]])

        XCTAssertEqual(
            sut.listOfTables,
            [Link(href: "/table.html")]
        )
    }

    func testNoListOfVideoClips() {
        let sut = makePublication()
        XCTAssertEqual(sut.listOfVideoClips, [])
    }
    
    func testListOfVideoClips() {
        let sut = makePublication(["lov": [PublicationCollection(links: [Link(href: "/video.mov")])]])
        
        XCTAssertEqual(
            sut.listOfVideoClips,
            [Link(href: "/video.mov")]
        )
    }
    
    private func makePublication(_ collections: [String: [PublicationCollection]] = [:]) -> Publication {
        return Publication(manifest: .init(metadata: Metadata(title: ""), links: [], readingOrder: [], subcollections: collections))
    }

}
