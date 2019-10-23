//
//  SampleGenerator.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import XCTest
import R2Shared
import R2Streamer

/// Testing constants
fileprivate struct TC {
    /// The total number epub in Samples
    static let numberOfPubSamples = 2
    /// The total number epubDirectory in Samples
    static let numberOfPubDirectorySamples = 2
    /// Name of test epubs contained in the Samples directory
    static let epub1 = "cc-shared-culture"
    static let epub2 = "SmokeTestFXL"
}

extension SampleGenerator: Loggable {}

internal class SampleGenerator: XCTest {
    lazy var pubUrls = [URL]()
    lazy var pubDirectoryUrls = [URL]()
    var samplesUrls: [URL] {
        return pubUrls + pubDirectoryUrls
    }

    /// Generate a dictionnary of the epubs at samplesUrls.
    ///
    /// - Returns: Dictionnayr of epubs at samplesUrls.
    internal func getEpubsForSamplesUrls() -> [String: PubBox] {
        var resources = [String: PubBox]()

        for url in samplesUrls {
            guard let result = parseEpub(at: url) else {
                XCTFail()
                continue
            }
            let pubTitle = result.publication.metadata.title 

            resources[pubTitle] = result
        }
        return resources
    }

    /// Parse Epub at the given URL.
    ///
    /// - Parameter url: The URL of the Epub to parse.
    /// - Returns: The resulting (publication, container) tuple (PubBox).
    internal func parseEpub(at url: URL) -> PubBox? {
        let pubBox: PubBox
        do {
            pubBox = try EpubParser.parse(at: url).0
        } catch {
            XCTFail("An exception occured while parsing publication at \(url.path)")
            log(.error, error)
            return nil
        }
        XCTAssertNotNil(pubBox.publication)
        XCTAssertNotNil(pubBox.associatedContainer)
        return pubBox
    }


    /// Parse CBZ at the given URL
    ///
    /// - Parameter url: The url of the CBZ to parse.
    /// - Returns: The resultint (publication, container) tuple (PubBox)
    internal func parseCbz(at url: URL) -> PubBox? {
        let pubBox: PubBox
        do {
            pubBox = try CbzParser.parse(at: url).0
        } catch {
            XCTFail("An exception occured while parsing publication at \(url.path)")
            log(.error, error)
            return nil
        }
        XCTAssertNotNil(pubBox.publication)
        XCTAssertNotNil(pubBox.associatedContainer)
        return pubBox
    }

    /// Get the URLs of the samples Publications.
    internal func getSampleEpubUrl() {
        // epubs
        if let pubUrl = getSamplesUrl(named: TC.epub1, ofType: "epub") {
            pubUrls.append(pubUrl)
        }
        if let pubUrl = getSamplesUrl(named: TC.epub2, ofType: "epub") {
            pubUrls.append(pubUrl)
        }
        XCTAssertTrue(pubUrls.count == TC.numberOfPubSamples)

        // epubDirectories
        if let pubUrl = getSamplesUrl(named: TC.epub1, ofType: nil) {
            pubDirectoryUrls.append(pubUrl)
        }
        if let pubUrl = getSamplesUrl(named: TC.epub2, ofType: nil) {
            pubDirectoryUrls.append(pubUrl)
        }
        XCTAssertTrue(pubDirectoryUrls.count == TC.numberOfPubDirectorySamples)
    }

    /// Return the absolute path to a ressource from the bundle/Samples.
    ///
    /// - Parameters:
    ///   - named: The name of the ressource.
    ///   - ofType: The type of the ressource. nil/"" if directory.
    /// - Returns: The fullpath to the ressource.
    internal func getSamplesUrl(named: String, ofType: String?) -> URL? {
        let bundle = Bundle(for: type(of: self))

        guard let path = bundle.path(forResource: "Samples/\(named)", ofType: ofType) else {
            XCTFail("Couldn't find resource name \(named) in Samples/")
            return nil
        }
        return URL(string: path)
    }
    
    internal func getSamplesFileURL(named: String, ofType: String?) -> URL? {
        let bundle = Bundle(for: type(of: self))
        return bundle.url(forResource: "Samples/\(named)", withExtension: ofType)
    }
    
}
