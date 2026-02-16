//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class DocumentTypesTests: XCTestCase {
    private let infoDictionary = NSDictionary(contentsOf: Fixtures().url(for: "DocumentTypes.plist").url) as! [String: Any]
    private var sut: DocumentTypes!

    override func setUp() {
        sut = DocumentTypes(infoDictionary: infoDictionary)
    }

    func testGetAll() throws {
        let all = sut.all

        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0], try DocumentType(
            name: "Foo Format",
            utis: [],
            preferredMediaType: XCTUnwrap(MediaType("application/vnd.bar")),
            mediaTypes: [
                XCTUnwrap(MediaType("application/vnd.bar")),
                XCTUnwrap(MediaType("application/vnd.bar2")),
            ],
            fileExtensions: ["foo", "foo2"]
        ))
        XCTAssertEqual(all[1], try DocumentType(
            name: "PDF Publication",
            utis: [],
            preferredMediaType: XCTUnwrap(MediaType("application/pdf")),
            mediaTypes: [
                XCTUnwrap(MediaType("application/pdf")),
            ],
            fileExtensions: ["pdff"]
        ))
        XCTAssertEqual(all[2], try DocumentType(
            name: "EPUB Publication",
            utis: ["org.idpf.epub-container"],
            preferredMediaType: XCTUnwrap(MediaType("application/epub+zip")),
            mediaTypes: [
                XCTUnwrap(MediaType("application/epub+zip")),
            ],
            fileExtensions: ["epub", "epub2"]
        ))
    }

    func testSupportedUTIs() {
        XCTAssertEqual(sut.supportedUTIs, ["org.idpf.epub-container"])
    }

    func testSupportedMediaTypes() throws {
        XCTAssertEqual(sut.supportedMediaTypes, try [
            XCTUnwrap(MediaType("application/epub+zip")),
            XCTUnwrap(MediaType("application/vnd.bar")),
            XCTUnwrap(MediaType("application/vnd.bar2")),
            XCTUnwrap(MediaType("application/pdf")),
        ])
    }

    func testSupportedFileExtensions() {
        XCTAssertEqual(sut.supportedFileExtensions, ["epub", "foo", "foo2", "pdff", "epub2"])
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
