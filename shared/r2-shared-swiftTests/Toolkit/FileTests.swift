//
//  FileTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class FileTests: XCTestCase {
    
    let fixtures = Fixtures(path: "Format")
    lazy var epubURL = fixtures.url(for: "epub.unknown")
    lazy var directoryURL = fixtures.url(for: "epub")
    
    func testIsDirectory() {
        XCTAssertTrue(File(url: directoryURL).isDirectory)
        XCTAssertFalse(File(url: epubURL).isDirectory)
    }
    
    func testFormatIsSniffedFromURL() {
        XCTAssertEqual(File(url: epubURL).format, .epub)
    }
    
    func testFormatUsesProvidedMediaTypeHint() {
        XCTAssertEqual(File(url: epubURL, mediaType: "application/pdf").format, .pdf)
    }
    
    func testFormatUsesProvidedFormat() {
        XCTAssertEqual(File(url: epubURL, format: .pdf).format, .pdf)
    }

}
