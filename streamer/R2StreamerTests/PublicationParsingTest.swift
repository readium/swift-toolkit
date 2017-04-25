//
//  GeneratePublicationsTest.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/3/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest
@testable import R2Streamer

extension PublicationParsingTest: Loggable {}

class PublicationParsingTest: XCTestCase {
    let sg = SampleGenerator()

    override func setUp() {
        R2StreamerEnableLog(withMinimumSeverityLevel: .debug)
        // Retrieve the samples URLs.
        sg.getSampleEpubUrl()
    }

    // Mark: - Tests methods.

    /// Try to parse the .epub samples.
    func testParseEpub() {
        for url in sg.pubUrls {
            // Parse the epub at URL and assert if failure.
            _ = sg.parseEpub(at: url)
        }
    }

    /// Attemp to parse the Epub directories samples.
    func testParseEpubDirectory() {
        for url in sg.pubDirectoryUrls {
            // Parse the epub at URL and assert if failure.
            _ = sg.parseEpub(at: url)
        }
    }

    func testParseCbz() {
        guard let url = sg.getSamplesUrl(named: "Cory_Doctorow_Futuristic_Tales_of_the_Here_and_Now", ofType: "cbz") else {
            XCTFail()
            return
        }
        _ = sg.parseCbz(at: url)
    }

    func testParseCbzDirectory() {
        guard let url = sg.getSamplesUrl(named: "Cory_Doctorow_Futuristic_Tales_of_the_Here_and_Now", ofType: nil) else {
            XCTFail()
            return
        }
        _ = sg.parseCbz(at: url)
    }
}
