//
//  DocumentTypesTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 26/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class DocumentTypesTests: XCTestCase {
    
    private let infoDictionary = NSDictionary(contentsOf: Fixtures().url(for: "DocumentTypes.plist")) as! [String: Any]
    private var sut: DocumentTypes!
    
    override func setUp() {
        sut = DocumentTypes(infoDictionary: infoDictionary)
    }

    func testGetAll() throws {
        let all = sut.all
        
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0], DocumentType(
            name: "Foo Format",
            utis: [],
            mediaTypes: [
                MediaType("application/vnd.bar")!,
                MediaType("application/vnd.bar2")!
            ],
            preferredMediaType: MediaType("application/vnd.bar")!,
            fileExtensions: ["foo", "foo2"],
            preferredFileExtension: "foo",
            format: Format(
                name: "Foo Format",
                mediaType: MediaType("application/vnd.bar")!,
                fileExtension: "foo"
            )
        ))
        XCTAssertEqual(all[1], DocumentType(
            name: "PDF Publication",
            utis: [],
            mediaTypes: [
                MediaType("application/pdf")!
            ],
            preferredMediaType: MediaType("application/pdf")!,
            fileExtensions: ["pdff"],
            preferredFileExtension: "pdff",
            format: Format(
                name: "PDF Publication",
                mediaType: MediaType("application/pdf")!,
                fileExtension: "pdff"
            )
        ))
        XCTAssertEqual(all[2], DocumentType(
            name: "EPUB Publication",
            utis: ["org.idpf.epub-container"],
            mediaTypes: [
                MediaType("application/epub+zip")!
            ],
            preferredMediaType: MediaType("application/epub+zip")!,
            fileExtensions: ["epub", "epub2"],
            preferredFileExtension: "epub",
            format: Format(
                name: "EPUB Publication",
                mediaType: MediaType("application/epub+zip")!,
                fileExtension: "epub"
            )
        ))
    }
    
    func testSupportedUTIs() {
        XCTAssertEqual(sut.supportedUTIs, ["org.idpf.epub-container"])
    }
    
    func testSupportedMediaTypes() {
        XCTAssertEqual(sut.supportedMediaTypes, [
            MediaType("application/vnd.bar")!,
            MediaType("application/vnd.bar2")!,
            MediaType("application/pdf")!,
            MediaType("application/epub+zip")!
        ])
    }

    func testSupportedFileExtensions() {
        XCTAssertEqual(sut.supportedFileExtensions, ["foo", "foo2", "pdff", "epub", "epub2"])
    }
    
    func testSupportsMediaType() {
        XCTAssertTrue(sut.supportsMediaType("application/epub+zip"))
        XCTAssertFalse(sut.supportsMediaType("text/html"))
    }
    
    func testSupportsMediaTypeIgnoresExtraParameters() {
        XCTAssertTrue(sut.supportsMediaType("application/epub+zip;param=value"))
    }
    
    func testSupportsFileExtension() {
        XCTAssertTrue(sut.supportsFileExtension("pdff"))
        XCTAssertFalse(sut.supportsFileExtension("bar"))
    }
    
    func testSupportsFileExtensionIgnoresCase() {
        XCTAssertTrue(sut.supportsFileExtension("FoO2"))
    }

}
