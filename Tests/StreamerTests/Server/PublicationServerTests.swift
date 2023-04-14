//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
@testable import R2Streamer
import XCTest

class PublicationServerTests: XCTestCase, Loggable {
    let fixtures = Fixtures()
    let streamer = Streamer()
    let publicationServer = PublicationServer()!

    private func testPublication(at url: URL) {
        let expect = expectation(description: "Publication tested")

        streamer.open(asset: FileAsset(url: url), allowUserInteraction: false) { result in
            guard case let .success(publication) = result else {
                XCTFail("Failed to parse \(url)")
                return
            }

            do {
                let endpoint = UUID().uuidString
                try self.publicationServer.add(publication, at: endpoint)
                self.verifyManifestJson(atEndpoint: endpoint) { expect.fulfill() }
            } catch {
                XCTFail("Failed to verify \(url)")
            }
        }

        waitForExpectations(timeout: 10, handler: nil)
    }

    private func verifyManifestJson(atEndpoint endPoint: String, completion: @escaping () -> Void) {
        guard var publicationUrl = publicationServer.baseURL else {
            XCTFail("PublicationServer baseURL not found")
            return
        }
        publicationUrl = publicationUrl.appendingPathComponent(endPoint)
        publicationUrl = publicationUrl.appendingPathComponent("manifest.json")

        // Define the request.
        let task = URLSession.shared.dataTask(with: publicationUrl, completionHandler: { data, _, error in
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
            completion()
        })
        // Fire the HTTP request...
        task.resume()
    }
}
