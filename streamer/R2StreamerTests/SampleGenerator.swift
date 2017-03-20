//
//  SampleGenerator.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import XCTest
import R2Streamer

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

extension SampleGenerator: Loggable {}

internal class SampleGenerator: XCTest {
    lazy var epubUrls = [URL]()
    lazy var epubDirectoryUrls = [URL]()
    var samplesUrls: [URL] {
        return epubUrls + epubDirectoryUrls
    }

    /// Generate a dictionnary of the epubs at samplesUrls.
    ///
    /// - Returns: Dictionnayr of epubs at samplesUrls.
    internal func getParsingResultsForSamplesUrls() -> [String: ParsingResult] {
        var ressources = [String: ParsingResult]()

        for url in samplesUrls {
            guard let result = parseEpub(at: url) else {
                XCTFail()
                continue
            }
            let epubTitle = result.publication.metadata.title ?? ""

            ressources[epubTitle] = result
        }
        return ressources
    }

    /// Parse Epub at the given URL.
    ///
    /// - Parameter url: The URL of the Epub to parse.
    /// - Returns: The resulting (publication, container) tuple (ParsingResult).
    internal func parseEpub(at url: URL) -> ParsingResult? {
        let parser = EpubParser()
        let parsingResult: ParsingResult

        do {
            parsingResult = try parser.parse(fileAtPath: url.path)
        } catch {
            XCTFail("An exception occured while parsing epub at \(url.path)")
            logValue(level: .error, error)
            return nil
        }
        XCTAssertNotNil(parsingResult.publication)
        XCTAssertNotNil(parsingResult.associatedContainer)
        return parsingResult
    }

    /// Get the URLs of the samples epubs.
    internal func getSampleEpubsUrl() {
        // epubs
        if let epubUrl = getSamplesUrl(named: TC.epub1, ofType: "epub") {
            epubUrls.append(epubUrl)
        }
        if let epubUrl = getSamplesUrl(named: TC.epub2, ofType: "epub") {
            epubUrls.append(epubUrl)
        }
        XCTAssertTrue(epubUrls.count == TC.numberOfEpubSamples)

        // epubDirectories
        if let epubUrl = getSamplesUrl(named: TC.epub1, ofType: nil) {
            epubDirectoryUrls.append(epubUrl)
        }
        if let epubUrl = getSamplesUrl(named: TC.epub2, ofType: nil) {
            epubDirectoryUrls.append(epubUrl)
        }
        XCTAssertTrue(epubDirectoryUrls.count == TC.numberOfEpubDirectorySamples)
    }

    /// Return the absolute path to a ressource from the bundle/Samples.
    ///
    /// - Parameters:
    ///   - named: The name of the ressource.
    ///   - ofType: The type of the ressource. nil/"" if directory.
    /// - Returns: The fullpath to the ressource.
    private func getSamplesUrl(named: String, ofType: String?) -> URL? {
        let bundle = Bundle(for: type(of: self))

        guard let path = bundle.path(forResource: "Samples/\(named)", ofType: ofType) else {
            XCTFail("Couldn't fine ressource name \(named) in Samples/")
            return nil
        }
        return URL(string: path)
    }
}
