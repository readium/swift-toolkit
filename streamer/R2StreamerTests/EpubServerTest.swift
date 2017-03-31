//
//  EpubServerTest.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/3/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest
import Foundation
@testable import R2Streamer

extension EpubServerTest: Loggable {}

class EpubServerTest: XCTestCase {
    let sg = SampleGenerator()
    var epubServer: EpubServer? = nil
    var ressources = [String: Epub]()

    override func setUp() {
        R2StreamerEnableLog(withMinimumSeverityLevel: .verbose)
        epubServer = EpubServer()
        guard epubServer != nil else {
            log(level: .error, "Error instanciating the epubServer")
            XCTFail()
            return
        }
        sg.getSampleEpubsUrl()
    }

    // Mark: - Tests methods.

    /// Add Epubs the the server then request the server about their 
    /// 'manifest.json'.
    func testAddEpub() {
        let results = sg.getEpubsForSamplesUrls()

        for element in results {
            let publication = element.value.publication
            let container = element.value.associatedContainer
            let endPoint = String(arc4random())

            print("Adding \(element.key)")
            do {
                try epubServer?.addEpub(forPublication: publication,
                                        withContainer: container,
                                        atEndpoint: endPoint)
            } catch {
                let epubTitle = publication.metadata.title
                XCTFail("An exception occured while adding epub [\(epubTitle)] to the server")
                logValue(level: .error, error)
            }
            verifyManifestJson(atEndpoint: endPoint)
        }
    }

    // MARK: - Fileprivate methods.

    fileprivate func verifyManifestJson(atEndpoint endPoint: String) {
        guard var epubUrl = epubServer?.baseURL else {
            XCTFail("EpubServer baseURL not found")
            return
        }
        epubUrl = epubUrl.appendingPathComponent(endPoint)
        epubUrl = epubUrl.appendingPathComponent("manifest.json")
        // Create the expectation.
        let expect = expectation(description: "EpubServer ressource exist at endPoint \(endPoint)/manifest.json")
        // Define the request.
        let task = URLSession.shared.dataTask(with: epubUrl, completionHandler: { (data, response, error) in
            guard error == nil else {
                self.logValue(level: .error, error)
                XCTFail()
                return
            }
            guard data != nil else {
                self.logValue(level: .error, "Data is empty.")
                XCTFail()
                return
            }

            //  let json = try JSONSerialization.jsonObject(with: data, options: [])
            // The expect is met.
            expect.fulfill()
        })
        // Fire the HTTP request...
        task.resume()

        // Wait for task{ expect.fulfill() } to be called with 2 seconds timeout
        // for requesting JSON manifest.
        waitForExpectations(timeout: 2) { error in
            XCTAssertNil(error, "Expectation failed: \(error)")
            guard let httpResponse = task.response as? HTTPURLResponse else {
                XCTFail("Invalid HTTP response.")
                return
            }
            print("\(httpResponse.statusCode)")
            guard httpResponse.statusCode == 200 else {
                XCTFail("HTTP reponse statuscode is not 200.")
                return
            }
        }
    }
}
