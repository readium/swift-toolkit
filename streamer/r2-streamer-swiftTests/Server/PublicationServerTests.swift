//
//  PublicationServerTests.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/3/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest
import Foundation
import R2Shared
@testable import R2Streamer

class PublicationServerTests: XCTestCase, Loggable {
    let sg = SampleGenerator()
    var publicationServer: PublicationServer? = nil
    var resources = [String: PubBox]()

    override func setUp() {
        R2EnableLog(withMinimumSeverityLevel: .info)
        publicationServer = PublicationServer()
        guard publicationServer != nil else {
            log(.error, "Error instanciating the publicationServer")
            XCTFail()
            return
        }
        sg.getSampleEpubUrl()
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
                try publicationServer?.add(publication, with: container, at: endPoint)
            } catch {
                let title = publication.metadata.title
                XCTFail("An exception occured while adding epub [\(title)] to the server")
                log(.error, error)
            }
            verifyManifestJson(atEndpoint: endPoint)
        }
    }

    // MARK: - Fileprivate methods.

    fileprivate func verifyManifestJson(atEndpoint endPoint: String) {
        guard var publicationUrl = publicationServer?.baseURL else {
            XCTFail("PublicationServer baseURL not found")
            return
        }
        publicationUrl = publicationUrl.appendingPathComponent(endPoint)
        publicationUrl = publicationUrl.appendingPathComponent("manifest.json")
        // Create the expectation.
        let expect = expectation(description: "PublicationServer resource exists at endPoint \(endPoint)/manifest.json")
        // Define the request.
        let task = URLSession.shared.dataTask(with: publicationUrl, completionHandler: { (data, response, error) in
            guard error == nil else {
                self.log(.error, error)
                XCTFail()
                return
            }
            guard data != nil else {
                self.log(.error, "Data is empty.")
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
            XCTAssertNil(error, "Expectation failed: \(String(describing: error))")
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
