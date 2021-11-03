//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
@testable import R2Shared

class FileAssetTests: XCTestCase {
    
    let fixtures = Fixtures(path: "Format")
    lazy var epubURL = fixtures.url(for: "epub.unknown")
    lazy var directoryURL = fixtures.url(for: "epub")
    
    func testMediaTypeIsSniffedFromURL() {
        XCTAssertEqual(FileAsset(url: epubURL).mediaType(), .epub)
    }
    
    func testMediaTypeUsesProvidedMediaTypeHint() {
        XCTAssertEqual(FileAsset(url: epubURL, mediaType: "application/pdf").mediaType(), .pdf)
    }
    
    func testMediaTypeUsesProvidedFormat() {
        XCTAssertEqual(FileAsset(url: epubURL, mediaType: .pdf).mediaType(), .pdf)
    }

}
