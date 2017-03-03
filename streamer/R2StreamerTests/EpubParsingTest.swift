//
//  GeneratePublicationsTest.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/3/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest
import CleanroomLogger
@testable import R2Streamer

/// Testing constants
fileprivate struct TC {
    /// The total number epub in Samples
    static let numberOfEpubSamples = 2
    /// The total number epubDirectory in Samples
    static let numberOfEpubDirectorySamples = 2
    /// Name of test epubs contained in the Samples directory
    static let epub1 = "cc-shared-culture"
    static let epub2 = "Le_tournant_hostile_extrait"
}

class EpubParsingTest: XCTestCase {
    lazy var epubPaths = [String]()
    lazy var epubDirectoryPaths = [String]()
    // Epub Containers array
    lazy var epubContainers = [Container]()
    // EpubDirectorie Containers array
    lazy var epubDirectoryContainers = [Container]()
    // The epub parser
    // TODO: Utiliser un epubParser unique, mais rework le parser d'abord
    //let epubParser: EpubParser

    // Mark: - Test methods

    /// Check that the bundle ressources Samples are accessibles
    func testGetSampleEpubsRessourcePaths() {
        // epubDirectories
        epubPaths.append(getSamplesRessourcePath(named: TC.epub1, ofType: nil))
        epubPaths.append(getSamplesRessourcePath(named: TC.epub2, ofType: nil))
        XCTAssertTrue(epubPaths.count == TC.numberOfEpubSamples)

        // epubs
        epubDirectoryPaths.append(getSamplesRessourcePath(named: TC.epub1, ofType: "epub"))
        epubDirectoryPaths.append(getSamplesRessourcePath(named: TC.epub2, ofType: "epub"))
        XCTAssertTrue(epubDirectoryPaths.count == TC.numberOfEpubDirectorySamples)
    }

    // Create Containers for the epub at epubPaths
    func testEpubContainerCreation() {
//        let fileManager = FileManager.default

//        for path in epubPaths {
//            guard fileManager.fileExists(atPath: path) else {
//                XCTFail("File at \(path) does not exist.")
//                break
//            }
//            do {
//
//            } catch {
//
//            }
//        }
    }

    // Create Containers for the epubDirectories at epubDirectoryPaths
    func testEpubDirectoryContainerCreation() {

    }

    // Mark: - Support methods

    /// Return the absolute path to a ressource from the bundle/Samples.
    ///
    /// - Parameters:
    ///   - named: The name of the ressource.
    ///   - ofType: The type of the ressource. "" if directory.
    /// - Returns: The fullpath to the ressource.
    private func getSamplesRessourcePath(named: String, ofType: String?) -> String {
        let bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: "Samples/\(named)", ofType: ofType) else {
            XCTFail("Couldn't fine ressource name \(named) in Samples/")
            return ""
        }
        return path
    }

}
