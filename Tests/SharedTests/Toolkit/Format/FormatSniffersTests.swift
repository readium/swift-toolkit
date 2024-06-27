//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class FormatSniffersTests: XCTestCase {
    let fixtures = Fixtures(path: "Format")
    let sut = DefaultFormatSniffer()
    
    func testSniffHintsUnknown() {
        XCTAssertNil(sut.sniffHints(.init(mediaType: nil, fileExtension: "unknown")))
        XCTAssertNil(sut.sniffHints(.init(mediaType: MediaType("application/unknown+zip")!)))
    }
    
    func testSniffHintsIgnoresExtensionCase() {
        XCTAssertEqual(
            sut.sniffHints(.init(mediaType: nil, fileExtension: "EPUB")),
            .epub
        )
    }
    
    func testSniffHintsIgnoresMediaTypeCase() {
        XCTAssertEqual(
            sut.sniffHints(.init(mediaType: MediaType("APPLICATION/EPUB+ZIP"))),
            .epub
        )
    }
    
    func testSniffHintsIgnoresMediaTypeExtraParameters() {
        XCTAssertEqual(
            sut.sniffHints(.init(mediaType: MediaType("application/epub+zip;param=value"))),
            .epub
        )
    }
    
    func testSniffBlobReadError() async {
        let error = ReadError.access(FileSystemError.fileNotFound(DebugError("error")))

        let result = await sut.sniffBlob(FormatSnifferBlob(source: FailureResource(error: error)))
        XCTAssertEqual(result, .failure(error))
    }
    
    func testSniffContainerReadError() async {
        let error = ReadError.access(FileSystemError.fileNotFound(DebugError("error")))

        let container = ProxyContainer { _ in
            FailureResource(error: error)
        }

        let result = await sut.sniffContainer(container)
        XCTAssertEqual(result, .failure(error))
    }
    
    func testSniffZIP() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .zip)), .zip)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "zip")), .zip)
        
        let result = await sut.sniffBlob(file("unknown.zip"))
        XCTAssertEqual(result, .success(.zip))
    }
    
    func testSniffEPUB() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .epub)), .epub)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "epub")), .zip)
        
        let result = await sut.sniffContainer(zip("epub.unknown"))
        XCTAssertEqual(result, .success(.epub))
    }

    private func file(_ path: String) async -> Resource {
        FileResource(file: fixtures.url(for: path))
    }
    
    private func zip(_ path: String) async -> Container {
        try! await ZIPArchiveOpener().open(
            resource: file(path),
            format: .zip
        ).get().container
    }
}

extension Format {
    static let epub = Format(
        specifications: .zip, .epub,
        mediaType: .epub,
        fileExtension: "epub"
    )

    static let zip = Format(
        specifications: .zip,
        mediaType: .zip,
        fileExtension: "zip"
    )
}
