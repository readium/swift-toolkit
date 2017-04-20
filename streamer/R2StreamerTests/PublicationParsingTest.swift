//
//  GeneratePublicationsTest.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/3/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest
@testable import R2Streamer

extension EpubParsingTest: Loggable {}

class EpubParsingTest: XCTestCase {
    let sg = SampleGenerator()

    override func setUp() {
        R2StreamerEnableLog(withMinimumSeverityLevel: .debug)
        // Retrieve the samples URLs.
        sg.getSamplePublicationsUrl()
    }

    // Mark: - Tests methods.

    /// Try to parse the .epub samples.
    func testParseEpub() {
        for url in sg.pubUrls {
            // Parse the epub at URL and assert if failure.
            _ = sg.parsePub(at: url)
        }
    }

    /// Attemp to parse the Epub directories samples.
    func testParseEpubDirectory() {
        for url in sg.pubDirectoryUrls {
            // Parse the epub at URL and assert if failure.
            _ = sg.parsePub(at: url)
        }
    }
}
