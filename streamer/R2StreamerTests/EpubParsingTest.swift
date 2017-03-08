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
        sg.getSampleEpubsRessourcePaths()
        sg.epubContainerCreation()
        sg.epubDirectoryContainerCreation()
    }

    // Mark: - Test methods

    /// EpubContainer -> publication
    func testParseEpubContainerToPublication() {
        // The epub parser
        let epubParser = EpubParser()

        for container in sg.epubContainers {
            var mutableContainer = container

            do {
                _ = try epubParser.parse(container: &mutableContainer)
            } catch {
                logValue(error)
                XCTFail("Publication init thrown \(error)")
            }
            // TODO: Define what to add as unit test.
        }
    }

    /// EpubDirectoryContainer -> publication
    func testParseEpubDirectoryContainerToPublication() {
        // The epub parser
        let epubParser = EpubParser()

        for container in sg.epubDirectoryContainers {
            var mutableContainer = container

            do {
                _ = try epubParser.parse(container: &mutableContainer)
            } catch {
                logValue(level: .error, error)
                XCTFail("Publication init thrown \(error)")
            }
            // TODO: Define what to add as unit test.
        }
    }
}
