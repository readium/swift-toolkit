//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
        XCTAssertEqual(all[0], DocumentType(
            name: "Foo Format",
            utis: [],
            preferredMediaType: MediaType("application/vnd.bar")!,
            mediaTypes: [
                MediaType("application/vnd.bar")!,
                MediaType("application/vnd.bar2")!,
            ],
            fileExtensions: ["foo", "foo2"]
        ))
        XCTAssertEqual(all[1], DocumentType(
            name: "PDF Publication",
            utis: [],
            preferredMediaType: MediaType("application/pdf")!,
            mediaTypes: [
                MediaType("application/pdf")!,
            ],
            fileExtensions: ["pdff"]
        ))
        XCTAssertEqual(all[2], DocumentType(
            name: "EPUB Publication",
            utis: ["org.idpf.epub-container"],
            preferredMediaType: MediaType("application/epub+zip")!,
            mediaTypes: [
                MediaType("application/epub+zip")!,
            ],
            fileExtensions: ["epub", "epub2"]
        ))
    }

    func testSupportedUTIs() {
        XCTAssertEqual(sut.supportedUTIs, ["org.idpf.epub-container"])
    }

    func testSupportedMediaTypes() {
        XCTAssertEqual(sut.supportedMediaTypes, [
            MediaType("application/epub+zip")!,
            MediaType("application/vnd.bar")!,
            MediaType("application/vnd.bar2")!,
            MediaType("application/pdf")!,
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
