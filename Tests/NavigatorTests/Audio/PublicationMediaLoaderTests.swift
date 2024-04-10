//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import XCTest

class PublicationMediaLoaderTests: XCTestCase {
    func testURLToHREF() {
        XCTAssertEqual(URL(string: "readium:relative/file.mp3")!.audioHREF, "relative/file.mp3")
        XCTAssertEqual(URL(string: "readium:/absolute/file.mp3")!.audioHREF, "/absolute/file.mp3")
        XCTAssertEqual(URL(string: "readiumfile:///directory/file.mp3")!.audioHREF, "file:///directory/file.mp3")
        XCTAssertEqual(URL(string: "readiumhttp:///domain.com/file.mp3")!.audioHREF, "http:///domain.com/file.mp3")
        XCTAssertEqual(URL(string: "readiumhttps:///domain.com/file.mp3")!.audioHREF, "https:///domain.com/file.mp3")

        // Encoded characters
        XCTAssertEqual(URL(string: "readium:relative/a%20file.mp3")!.audioHREF, "relative/a%20file.mp3")
        XCTAssertEqual(URL(string: "readium:/absolute/a%20file.mp3")!.audioHREF, "/absolute/a%20file.mp3")
        XCTAssertEqual(URL(string: "readiumfile:///directory/a%20file.mp3")!.audioHREF, "file:///directory/a%20file.mp3")
        XCTAssertEqual(URL(string: "readiumhttp:///domain.com/a%20file.mp3")!.audioHREF, "http:///domain.com/a%20file.mp3")
        XCTAssertEqual(URL(string: "readiumhttps:///domain.com/a%20file.mp3")!.audioHREF, "https:///domain.com/a%20file.mp3")

        // Ignores if the r2 prefix is missing.
        XCTAssertNil(URL(string: "relative/file.mp3")!.audioHREF)
        XCTAssertNil(URL(string: "file:///directory/file.mp3")!.audioHREF)
        XCTAssertNil(URL(string: "http:///domain.com/file.mp3")!.audioHREF)
    }
}
