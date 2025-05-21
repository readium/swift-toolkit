//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class FormatSniffersTests: XCTestCase {
    let fixtures = Fixtures(path: "Format")
    let sut = DefaultFormatSniffer()

    func testSniffHintsUnknown() {
        XCTAssertNil(sut.sniffHints(fileExtension: "unknown"))
        XCTAssertNil(sut.sniffHints(mediaType: MediaType("application/unknown+zip")!))
    }

    func testSniffHintsIgnoresExtensionCase() {
        XCTAssertEqual(
            sut.sniffHints(fileExtension: "EPUB"),
            .epub
        )
    }

    func testSniffHintsIgnoresMediaTypeCase() {
        XCTAssertEqual(
            sut.sniffHints(mediaType: "APPLICATION/EPUB+ZIP"),
            .epub
        )
    }

    func testSniffHintsIgnoresMediaTypeExtraParameters() {
        XCTAssertEqual(
            sut.sniffHints(mediaType: "application/epub+zip;param=value"),
            .epub
        )
    }

    func testSniffBlobReadError() async {
        let error = ReadError.access(.fileSystem(.fileNotFound(DebugError("error"))))

        let result = await sut.sniffBlob(FormatSnifferBlob(source: FailureResource(error: error)))
        XCTAssertEqual(result, .failure(error))
    }

    func testSniffContainerReadError() async {
        let error = ReadError.access(.fileSystem(.fileNotFound(DebugError("error"))))

        let container = ProxyContainer { _ in
            FailureResource(error: error)
        }

        let result = await sut.sniffContainer(container)
        XCTAssertEqual(result, .failure(error))
    }

    func testSniffAudio() {
        // AAC
        let aac = Format(specifications: .aac, mediaType: .aac, fileExtension: "aac")
        XCTAssertEqual(sut.sniffHints(fileExtension: "aac"), aac)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/aac"), aac)

        // AIFF
        let aiff = Format(specifications: .aiff, mediaType: .aiff, fileExtension: "aiff")
        XCTAssertEqual(sut.sniffHints(fileExtension: "aiff"), aiff)
        XCTAssertEqual(sut.sniffHints(fileExtension: "aif"), aiff)
        XCTAssertEqual(sut.sniffHints(fileExtension: "aifc"), aiff)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/aiff"), aiff)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/x-aiff"), aiff)

        // FLAC
        let flac = Format(specifications: .flac, mediaType: .flac, fileExtension: "flac")
        XCTAssertEqual(sut.sniffHints(fileExtension: "flac"), flac)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/flac"), flac)

        // MP3
        let mp3 = Format(specifications: .mp3, mediaType: .mp3, fileExtension: "mp3")
        XCTAssertEqual(sut.sniffHints(fileExtension: "mp3"), mp3)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/mpeg"), mp3)

        // MP4
        let mp4 = Format(specifications: .mp4, mediaType: .mp4, fileExtension: "mp4")
        XCTAssertEqual(sut.sniffHints(fileExtension: "mp4"), mp4)
        XCTAssertEqual(sut.sniffHints(fileExtension: "m4a"), mp4)
        XCTAssertEqual(sut.sniffHints(fileExtension: "m4b"), mp4)
        XCTAssertEqual(sut.sniffHints(fileExtension: "m4p"), mp4)
        XCTAssertEqual(sut.sniffHints(fileExtension: "m4r"), mp4)
        XCTAssertEqual(sut.sniffHints(fileExtension: "alac"), mp4)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/mp4"), mp4)

        // OGG
        let ogg = Format(specifications: .ogg, mediaType: .ogg, fileExtension: "ogg")
        XCTAssertEqual(sut.sniffHints(fileExtension: "ogg"), ogg)
        XCTAssertEqual(sut.sniffHints(fileExtension: "oga"), ogg)
        XCTAssertEqual(sut.sniffHints(fileExtension: "mogg"), ogg)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/ogg"), ogg)

        // OPUS
        let opus = Format(specifications: .opus, mediaType: .opus, fileExtension: "opus")
        XCTAssertEqual(sut.sniffHints(fileExtension: "opus"), opus)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/opus"), opus)

        // WAV
        let wav = Format(specifications: .wav, mediaType: .wav, fileExtension: "wav")
        XCTAssertEqual(sut.sniffHints(fileExtension: "wav"), wav)
        XCTAssertEqual(sut.sniffHints(fileExtension: "wave"), wav)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/wav"), wav)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/x-wav"), wav)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/wave"), wav)

        // WebM
        let webm = Format(specifications: .webm, mediaType: .webmAudio, fileExtension: "webm")
        XCTAssertEqual(sut.sniffHints(fileExtension: "webm"), webm)
        XCTAssertEqual(sut.sniffHints(mediaType: "audio/webm"), webm)
    }

    func testSniffLanguage() {
        // JavaScript
        let js = Format(specifications: .javascript, mediaType: .javascript, fileExtension: "js")
        XCTAssertEqual(sut.sniffHints(fileExtension: "js"), js)
        XCTAssertEqual(sut.sniffHints(mediaType: "text/javascript"), js)
        XCTAssertEqual(sut.sniffHints(mediaType: "application/javascript"), js)

        // CSS
        let css = Format(specifications: .css, mediaType: .css, fileExtension: "css")
        XCTAssertEqual(sut.sniffHints(fileExtension: "css"), css)
        XCTAssertEqual(sut.sniffHints(mediaType: "text/css"), css)
    }

    func testSniffBitmap() {
        // AVIF
        let avif = Format(specifications: .avif, mediaType: .avif, fileExtension: "avif")
        XCTAssertEqual(sut.sniffHints(fileExtension: "avif"), avif)
        XCTAssertEqual(sut.sniffHints(fileExtension: "avifs"), avif)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/avif"), avif)

        // BMP
        let bmp = Format(specifications: .bmp, mediaType: .bmp, fileExtension: "bmp")
        XCTAssertEqual(sut.sniffHints(fileExtension: "bmp"), bmp)
        XCTAssertEqual(sut.sniffHints(fileExtension: "dib"), bmp)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/bmp"), bmp)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/x-bmp"), bmp)

        // GIF
        let gif = Format(specifications: .gif, mediaType: .gif, fileExtension: "gif")
        XCTAssertEqual(sut.sniffHints(fileExtension: "gif"), gif)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/gif"), gif)

        // JPEG
        let jpeg = Format(specifications: .jpeg, mediaType: .jpeg, fileExtension: "jpg")
        XCTAssertEqual(sut.sniffHints(fileExtension: "jpg"), jpeg)
        XCTAssertEqual(sut.sniffHints(fileExtension: "jpeg"), jpeg)
        XCTAssertEqual(sut.sniffHints(fileExtension: "jpe"), jpeg)
        XCTAssertEqual(sut.sniffHints(fileExtension: "jif"), jpeg)
        XCTAssertEqual(sut.sniffHints(fileExtension: "jfif"), jpeg)
        XCTAssertEqual(sut.sniffHints(fileExtension: "jfi"), jpeg)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/jpeg"), jpeg)

        // PNG
        let png = Format(specifications: .png, mediaType: .png, fileExtension: "png")
        XCTAssertEqual(sut.sniffHints(fileExtension: "png"), png)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/png"), png)

        // TIFF
        let tiff = Format(specifications: .tiff, mediaType: .tiff, fileExtension: "tiff")
        XCTAssertEqual(sut.sniffHints(fileExtension: "tiff"), tiff)
        XCTAssertEqual(sut.sniffHints(fileExtension: "tif"), tiff)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/tiff"), tiff)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/tiff-fx"), tiff)

        // WebP
        let webp = Format(specifications: .webp, mediaType: .webp, fileExtension: "webp")
        XCTAssertEqual(sut.sniffHints(fileExtension: "webp"), webp)
        XCTAssertEqual(sut.sniffHints(mediaType: "image/webp"), webp)
    }

    func testSniffCBR() async {
        let cbr = Format(specifications: .rar, .informalComic, mediaType: .cbr, fileExtension: "cbr")
        XCTAssertEqual(sut.sniffHints(mediaType: "application/vnd.comicbook-rar"), cbr)
        XCTAssertEqual(sut.sniffHints(mediaType: "application/x-cbr"), cbr)
        XCTAssertEqual(sut.sniffHints(fileExtension: "cbr"), cbr)
    }

    func testSniffCBZ() async {
        let cbz = Format(specifications: .zip, .informalComic, mediaType: .cbz, fileExtension: "cbz")
        XCTAssertEqual(sut.sniffHints(mediaType: "application/vnd.comicbook+zip"), cbz)
        XCTAssertEqual(sut.sniffHints(mediaType: "application/x-cbz"), cbz)
        XCTAssertEqual(sut.sniffHints(fileExtension: "cbz"), cbz)

        let result = await sut.sniffContainer(zip("cbz.unknown"), refining: .zip)
        XCTAssertEqual(result, .success(cbz))
    }

    func testSniffEPUB() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .epub), .epub)
        XCTAssertEqual(sut.sniffHints(fileExtension: "epub"), .epub)

        var result = await sut.sniffContainer(zip("epub.unknown"), refining: .zip)
        XCTAssertEqual(result, .success(.epub))

        result = await sut.sniffContainer(folder("epub"))
        XCTAssertEqual(result, .success(Format(specifications: .epub)))
    }

    func testSniffHTML() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .html), .html)
        XCTAssertEqual(sut.sniffHints(fileExtension: "html"), .html)
        XCTAssertEqual(sut.sniffHints(fileExtension: "htm"), .html)

        var result = await sut.sniffBlob(file("html.unknown"))
        XCTAssertEqual(result, .success(.html))

        result = await sut.sniffBlob(file("html-doctype-case.unknown"))
        XCTAssertEqual(result, .success(.html))
    }

    func testSniffJSON() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .json), .json)
        XCTAssertEqual(sut.sniffHints(mediaType: .problemDetails), .jsonProblemDetails)
        XCTAssertEqual(sut.sniffHints(fileExtension: "json"), .json)

        let result = await sut.sniffBlob(file("json.unknown"))
        XCTAssertEqual(result, .success(.json))
    }

    func testSniffLCPLicense() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .lcpLicenseDocument), .lcpLicense)
        XCTAssertEqual(sut.sniffHints(fileExtension: "lcpl"), .lcpLicense)

        let result = await sut.sniffBlob(file("lcpl.unknown"))
        XCTAssertEqual(result, .success(.lcpLicense))
    }

    func testSniffLCPProtectedAudiobook() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .lcpProtectedAudiobook), .lcpa)
        XCTAssertEqual(sut.sniffHints(fileExtension: "lcpa"), .lcpa)

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
        XCTAssertEqual(sut.sniffHints(mediaType: .lcpProtectedPDF), .lcpdf)
        XCTAssertEqual(sut.sniffHints(fileExtension: "lcpdf"), .lcpdf)

        let result = await sut.sniffContainer(zip("pdf-lcp.unknown"))
        XCTAssertEqual(result, .success(.lcpdf))
    }

    func testSniffOPDS1Feed() async {
        let opds1 = Format(
            specifications: .xml, .opds1Catalog,
            mediaType: .opds1,
            fileExtension: "xml"
        )

        XCTAssertEqual(sut.sniffHints(mediaType: "application/atom+xml;profile=opds-catalog"), opds1)

        let result = await sut.sniffBlob(file("opds1-feed.unknown"))
        XCTAssertEqual(result, .success(opds1))
    }

    func testSniffOPDS1Entry() async {
        let opds1 = Format(
            specifications: .xml, .opds1Entry,
            mediaType: .opds1Entry,
            fileExtension: "xml"
        )

        XCTAssertEqual(sut.sniffHints(mediaType: "application/atom+xml;type=entry;profile=opds-catalog"), opds1)

        let result = await sut.sniffBlob(file("opds1-entry.unknown"))
        XCTAssertEqual(result, .success(opds1))
    }

    func testSniffOPDS2Feed() async {
        let opds2 = Format(
            specifications: .json, .opds2Catalog,
            mediaType: .opds2,
            fileExtension: "json"
        )

        XCTAssertEqual(sut.sniffHints(mediaType: "application/opds+json"), opds2)

        let result = await sut.sniffBlob(file("opds2-feed.json"))
        XCTAssertEqual(result, .success(opds2))
    }

    func testSniffOPDS2Publication() async {
        let opds2 = Format(
            specifications: .json, .opds2Publication,
            mediaType: .opds2Publication,
            fileExtension: "json"
        )

        XCTAssertEqual(sut.sniffHints(mediaType: "application/opds-publication+json"), opds2)

        let result = await sut.sniffBlob(file("opds2-publication.json"))
        XCTAssertEqual(result, .success(opds2))
    }

    func testSniffOPDSAuthentication() async {
        let opdsAuth = Format(
            specifications: .json, .opdsAuthentication,
            mediaType: .opdsAuthentication,
            fileExtension: "json"
        )

        XCTAssertEqual(sut.sniffHints(mediaType: "application/opds-authentication+json"), opdsAuth)
        XCTAssertEqual(sut.sniffHints(mediaType: "application/vnd.opds.authentication.v1.0+json"), opdsAuth)

        let result = await sut.sniffBlob(file("opds-authentication.json"))
        XCTAssertEqual(result, .success(opdsAuth))
    }

    func testSniffPDF() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .pdf), .pdf)
        XCTAssertEqual(sut.sniffHints(fileExtension: "pdf"), .pdf)

        let result = await sut.sniffBlob(file("pdf.unknown"))
        XCTAssertEqual(result, .success(.pdf))
    }

    func testSniffRPF() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .readiumWebPub), .rpfWebPub)
        XCTAssertEqual(sut.sniffHints(mediaType: .readiumAudiobook), .rpfAudiobook)
        XCTAssertEqual(sut.sniffHints(fileExtension: "audiobook"), .rpfAudiobook)
        XCTAssertEqual(sut.sniffHints(mediaType: .divina), .rpfDivina)
        XCTAssertEqual(sut.sniffHints(fileExtension: "divina"), .rpfDivina)

        var result = await sut.sniffContainer(zip("webpub-package.unknown"))
        XCTAssertEqual(result, .success(.rpfWebPub))

        result = await sut.sniffContainer(zip("divina-package.unknown"))
        XCTAssertEqual(result, .success(.rpfDivina))

        result = await sut.sniffContainer(zip("audiobook-package.unknown"))
        XCTAssertEqual(result, .success(.rpfAudiobook))
    }

    func testSniffRWPM() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .readiumWebPubManifest), .rwpmWebPub)
        XCTAssertEqual(sut.sniffHints(mediaType: .readiumAudiobookManifest), .rwpmAudiobook)
        XCTAssertEqual(sut.sniffHints(mediaType: .divinaManifest), .rwpmDivina)

        var result = await sut.sniffBlob(file("webpub.json"))
        XCTAssertEqual(result, .success(.rwpmWebPub))

        result = await sut.sniffBlob(file("divina.json"))
        XCTAssertEqual(result, .success(.rwpmDivina))

        result = await sut.sniffBlob(file("audiobook.json"))
        XCTAssertEqual(result, .success(.rwpmAudiobook))
    }

    func testSniffRAR() async {
        let rar = Format(specifications: .rar, mediaType: .rar, fileExtension: "rar")

        XCTAssertEqual(sut.sniffHints(mediaType: .rar), rar)
        XCTAssertEqual(sut.sniffHints(mediaType: MediaType("application/x-rar")!), rar)
        XCTAssertEqual(sut.sniffHints(mediaType: MediaType("application/x-rar-compressed")!), rar)
        XCTAssertEqual(sut.sniffHints(fileExtension: "rar"), rar)
    }

    func testSniffXHTML() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .xhtml), .xhtml)
        XCTAssertEqual(sut.sniffHints(fileExtension: "xhtml"), .xhtml)
        XCTAssertEqual(sut.sniffHints(fileExtension: "xht"), .xhtml)

        let result = await sut.sniffBlob(file("xhtml.unknown"))
        XCTAssertEqual(result, .success(.xhtml))
    }

    func testSniffXML() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .xml), .xml)
        XCTAssertEqual(sut.sniffHints(fileExtension: "xml"), .xml)
    }

    func testSniffZAB() async {
        let zab = Format(specifications: .zip, .informalAudiobook, mediaType: .zab, fileExtension: "zab")
        XCTAssertEqual(sut.sniffHints(mediaType: .zab), zab)
        XCTAssertEqual(sut.sniffHints(fileExtension: "zab"), zab)

        let result = await sut.sniffContainer(zip("zab.unknown"), refining: .zip)
        XCTAssertEqual(result, .success(zab))
    }

    func testSniffZIP() async {
        XCTAssertEqual(sut.sniffHints(mediaType: .zip), .zip)
        XCTAssertEqual(sut.sniffHints(fileExtension: "zip"), .zip)

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

private extension FormatSniffer {
    func sniffHints(fileExtension: String) -> Format? {
        sniffHints(.init(fileExtension: FileExtension(rawValue: fileExtension)))
    }

    func sniffHints(mediaType: MediaType) -> Format? {
        sniffHints(.init(mediaType: mediaType))
    }

    func sniffHints(mediaType: String) -> Format? {
        sniffHints(.init(mediaType: MediaType(mediaType)!))
    }
}

extension Format {
    static let epub = Format(specifications: .zip, .epub, mediaType: .epub, fileExtension: "epub")
    static let html = Format(specifications: .xml, .html, mediaType: .html, fileExtension: "html")
    static let json = Format(specifications: .json, mediaType: .json, fileExtension: "json")
    static let jsonProblemDetails = Format(specifications: .json, .problemDetails, mediaType: .json, fileExtension: "json")
    static let lcpLicense = Format(specifications: .json, .lcpLicense, mediaType: .lcpLicenseDocument, fileExtension: "lcpl")
    static let lcpdf = Format(specifications: .zip, .rpf, .lcp, mediaType: .lcpProtectedPDF, fileExtension: "lcpdf")
    static let lcpa = Format(specifications: .zip, .rpf, .lcp, mediaType: .lcpProtectedAudiobook, fileExtension: "lcpa")
    static let lcpDivina = Format(specifications: .zip, .rpf, .lcp, mediaType: .divina, fileExtension: "divina")
    static let pdf = Format(specifications: .pdf, mediaType: .pdf, fileExtension: "pdf")
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
