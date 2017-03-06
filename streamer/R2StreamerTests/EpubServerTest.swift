//
//  EpubServerTest.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/3/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest
@testable import R2Streamer

class EpubServerTest: XCTestCase {
    let sg = SampleGenerator()
    let epubServer = EpubServer()

    override func setUp() {
        sg.getSampleEpubsRessourcePaths()
        sg.epubContainerCreation()
        sg.epubDirectoryContainerCreation()
    }
    // Mark: - test

    func testAddEpub() {
        
    }
}
