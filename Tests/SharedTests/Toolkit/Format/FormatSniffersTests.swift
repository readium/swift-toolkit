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

    func testSniffEPUB() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .epub)), .epub)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "epub")), .epub)

        var result = await sut.sniffContainer(zip("epub.unknown"), refining: .zip)
        XCTAssertEqual(result, .success(.epub))

        result = await sut.sniffContainer(folder("epub"))
        XCTAssertEqual(result, .success(Format(specifications: .epub)))
    }

    func testSniffHTML() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .html)), .html)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "html")), .html)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "htm")), .html)

        var result = await sut.sniffBlob(file("html.unknown"))
        XCTAssertEqual(result, .success(.html))

        result = await sut.sniffBlob(file("html-doctype-case.unknown"))
        XCTAssertEqual(result, .success(.html))
    }

    func testSniffJSON() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .json)), .json)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .problemDetails)), .jsonProblemDetails)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "json")), .json)

        let result = await sut.sniffBlob(file("json.unknown"))
        XCTAssertEqual(result, .success(.json))
    }

    func testSniffLCPLicense() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .lcpLicenseDocument)), .lcpLicense)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "lcpl")), .lcpLicense)

        let result = await sut.sniffBlob(file("lcpl.unknown"))
        XCTAssertEqual(result, .success(.lcpLicense))
    }

    func testSniffLCPProtectedAudiobook() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .lcpProtectedAudiobook)), .lcpa)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "lcpa")), .lcpa)

        let result = await sut.sniffContainer(zip("audiobook-lcp.unknown"))
        XCTAssertEqual(result, .success(.lcpa))
    }

    func testSniffLCPProtectedDivina() async {
        let result = await sut.sniffContainer(zip("divina-lcp.unknown"))
        XCTAssertEqual(result, .success(.lcpDivina))
    }

    func testSniffLCPProtectedEPUB() async {
        let expected = Format(specifications: .zip, .epub, .lcp, mediaType: .epub, fileExtension: "epub")

        var result = await sut.sniffContainer(zip("epub-lcp.unknown"), refining: .zip)
        XCTAssertEqual(result, .success(expected))

        result = await sut.sniffContainer(zip("epub-lcp-without-license.unknown"), refining: .zip)
        XCTAssertEqual(result, .success(expected))
    }

    func testSniffLCPProtectedPDF() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .lcpProtectedPDF)), .lcpdf)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "lcpdf")), .lcpdf)

        let result = await sut.sniffContainer(zip("pdf-lcp.unknown"))
        XCTAssertEqual(result, .success(.lcpdf))
    }

    func testSniffPDF() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .pdf)), .pdf)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "pdf")), .pdf)

        let result = await sut.sniffBlob(file("pdf.unknown"))
        XCTAssertEqual(result, .success(.pdf))
    }

    func testSniffRPF() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .readiumWebPub)), .rpfWebPub)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .readiumAudiobook)), .rpfAudiobook)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "audiobook")), .rpfAudiobook)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .divina)), .rpfDivina)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "divina")), .rpfDivina)

        var result = await sut.sniffContainer(zip("webpub-package.unknown"))
        XCTAssertEqual(result, .success(.rpfWebPub))

        result = await sut.sniffContainer(zip("divina-package.unknown"))
        XCTAssertEqual(result, .success(.rpfDivina))

        result = await sut.sniffContainer(zip("audiobook-package.unknown"))
        XCTAssertEqual(result, .success(.rpfAudiobook))
    }

    func testSniffRWPM() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .readiumWebPubManifest)), .rwpmWebPub)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .readiumAudiobookManifest)), .rwpmAudiobook)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .divinaManifest)), .rwpmDivina)

        var result = await sut.sniffBlob(file("webpub.json"))
        XCTAssertEqual(result, .success(.rwpmWebPub))

        result = await sut.sniffBlob(file("divina.json"))
        XCTAssertEqual(result, .success(.rwpmDivina))

        result = await sut.sniffBlob(file("audiobook.json"))
        XCTAssertEqual(result, .success(.rwpmAudiobook))
    }

    func testSniffRAR() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .rar)), .rar)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: MediaType("application/x-rar")!)), .rar)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: MediaType("application/x-rar-compressed")!)), .rar)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "rar")), .rar)
    }

    func testSniffXHTML() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .xhtml)), .xhtml)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "xhtml")), .xhtml)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "xht")), .xhtml)

        let result = await sut.sniffBlob(file("xhtml.unknown"))
        XCTAssertEqual(result, .success(.xhtml))
    }

    func testSniffXML() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .xml)), .xml)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "xml")), .xml)
    }

    func testSniffZIP() async {
        XCTAssertEqual(sut.sniffHints(.init(mediaType: .zip)), .zip)
        XCTAssertEqual(sut.sniffHints(.init(mediaType: nil, fileExtension: "zip")), .zip)

        let result = await sut.sniffBlob(file("unknown.zip"))
        XCTAssertEqual(result, .success(.zip))
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

    private func folder(_ path: String) async -> Container {
        try! await DirectoryContainer(directory: fixtures.url(for: path))
    }
}

extension Format {
    static let epub = Format(specifications: .zip, .epub, mediaType: .epub, fileExtension: "epub")
    static let html = Format(specifications: .html, mediaType: .html, fileExtension: "html")
    static let json = Format(specifications: .json, mediaType: .json, fileExtension: "json")
    static let jsonProblemDetails = Format(specifications: .json, .problemDetails, mediaType: .json, fileExtension: "json")
    static let lcpLicense = Format(specifications: .json, .lcpLicense, mediaType: .lcpLicenseDocument, fileExtension: "lcpl")
    static let lcpdf = Format(specifications: .zip, .rpf, .lcp, mediaType: .lcpProtectedPDF, fileExtension: "lcpdf")
    static let lcpa = Format(specifications: .zip, .rpf, .lcp, mediaType: .lcpProtectedAudiobook, fileExtension: "lcpa")
    static let lcpDivina = Format(specifications: .zip, .rpf, .lcp, mediaType: .divina, fileExtension: "divina")
    static let pdf = Format(specifications: .pdf, mediaType: .pdf, fileExtension: "pdf")
    static let rar = Format(specifications: .rar, mediaType: .rar, fileExtension: "rar")
    static let rpfWebPub = Format(specifications: .zip, .rpf, mediaType: .readiumWebPub, fileExtension: "webpub")
    static let rpfAudiobook = Format(specifications: .zip, .rpf, mediaType: .readiumAudiobook, fileExtension: "audiobook")
    static let rpfDivina = Format(specifications: .zip, .rpf, mediaType: .divina, fileExtension: "divina")
    static let rwpmWebPub = Format(specifications: .json, .rwpm, mediaType: .readiumWebPubManifest, fileExtension: "json")
    static let rwpmAudiobook = Format(specifications: .json, .rwpm, mediaType: .readiumAudiobookManifest, fileExtension: "json")
    static let rwpmDivina = Format(specifications: .json, .rwpm, mediaType: .divinaManifest, fileExtension: "json")
    static let xhtml = Format(specifications: .xml, .html, mediaType: .xhtml, fileExtension: "xhtml")
    static let xml = Format(specifications: .xml, mediaType: .xml, fileExtension: "xml")
    static let zip = Format(specifications: .zip, mediaType: .zip, fileExtension: "zip")
}
