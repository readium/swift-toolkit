//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Navigator
import XCTest

class PublicationMediaLoaderTests: XCTestCase {
    func testURLToHREF() {
        XCTAssertEqual(URL(string: "r2:relative/file.mp3")!.audioHREF, "relative/file.mp3")
        XCTAssertEqual(URL(string: "r2:/absolute/file.mp3")!.audioHREF, "/absolute/file.mp3")
        XCTAssertEqual(URL(string: "r2file:///directory/file.mp3")!.audioHREF, "file:///directory/file.mp3")
        XCTAssertEqual(URL(string: "r2http:///domain.com/file.mp3")!.audioHREF, "http:///domain.com/file.mp3")
        XCTAssertEqual(URL(string: "r2https:///domain.com/file.mp3")!.audioHREF, "https:///domain.com/file.mp3")
        
        // Encoded characters
        XCTAssertEqual(URL(string: "r2:relative/a%20file.mp3")!.audioHREF, "relative/a%20file.mp3")
        XCTAssertEqual(URL(string: "r2:/absolute/a%20file.mp3")!.audioHREF, "/absolute/a%20file.mp3")
        XCTAssertEqual(URL(string: "r2file:///directory/a%20file.mp3")!.audioHREF, "file:///directory/a%20file.mp3")
        XCTAssertEqual(URL(string: "r2http:///domain.com/a%20file.mp3")!.audioHREF, "http:///domain.com/a%20file.mp3")
        XCTAssertEqual(URL(string: "r2https:///domain.com/a%20file.mp3")!.audioHREF, "https:///domain.com/a%20file.mp3")
        
        // Ignores if the r2 prefix is missing.
        XCTAssertNil(URL(string: "relative/file.mp3")!.audioHREF)
        XCTAssertNil(URL(string: "file:///directory/file.mp3")!.audioHREF)
        XCTAssertNil(URL(string: "http:///domain.com/file.mp3")!.audioHREF)
    }
}
