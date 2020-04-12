//
//  FormatSnifferTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class FormatSnifferTests: XCTestCase {

    let fixtures = Fixtures(path: "Format")
    
    func testSniffIgnoresExtensionCase() {
        XCTAssertEqual(Format.of(fileExtensions: ["EPUB"]), .EPUB)
    }
    
    func testSniffIgnoresMediaTypeCase() {
        XCTAssertEqual(Format.of(mediaTypes: ["APPLICATION/EPUB+ZIP"]), .EPUB)
    }
    
    func testSniffIgnoresMediaTypeExtraParameters() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/epub+zip;param=value"]), .EPUB)
    }
    
    func testSniffFromMetadata() {
        XCTAssertEqual(Format.of(fileExtensions: ["audiobook"]), .Audiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+zip"]), .Audiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+zip"], fileExtensions: ["audiobook"]), .Audiobook)
    }
    
    func testSniffFromAFile() {
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook.json")), .AudiobookManifest)
    }
    
    func testSniffFromBytes() {
        let data = try! Data(contentsOf: fixtures.url(for: "audiobook.json"))
        XCTAssertEqual(Format.of({ data }), .AudiobookManifest)
    }

    func testSniffLightUnknownFormat() {
        XCTAssertNil(Format.of(mediaTypes: ["text/plain"]))
    }
    
    func testSniffHeavyUnknownFormat() {
        XCTAssertNil(Format.of(fixtures.url(for: "unknown")))
    }
    
    func testSniffLightAudiobook() {
        XCTAssertEqual(Format.of(fileExtensions: ["audiobook"]), .Audiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+zip"]), .Audiobook)
    }
    
    func testSniffHeavyAudiobook() {
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook-package.unknown")), .Audiobook)
    }
    
    func testSniffLightAudiobookManifest() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+json"]), .AudiobookManifest)
    }
    
    func testSniffHeavyAudiobookManifest() {
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook.json")), .AudiobookManifest)
    }
    
    func testSniffBMP() {
        XCTAssertEqual(Format.of(fileExtensions: ["bmp"]), .BMP)
        XCTAssertEqual(Format.of(fileExtensions: ["dib"]), .BMP)
        XCTAssertEqual(Format.of(mediaTypes: ["image/bmp"]), .BMP)
        XCTAssertEqual(Format.of(mediaTypes: ["image/x-bmp"]), .BMP)
    }
    
    func testSniffLightCBZ() {
        XCTAssertEqual(Format.of(fileExtensions: ["cbz"]), .CBZ)
        XCTAssertEqual(Format.of(mediaTypes: ["application/vnd.comicbook+zip"]), .CBZ)
        XCTAssertEqual(Format.of(mediaTypes: ["application/x-cbz"]), .CBZ)
        XCTAssertEqual(Format.of(mediaTypes: ["application/x-cbr"]), .CBZ)
    }
    
    func testSniffHeavyCBZ() {
        XCTAssertEqual(Format.of(fixtures.url(for: "cbz.unknown")), .CBZ)
    }
    
    func testSniffLightDiViNa() {
        XCTAssertEqual(Format.of(fileExtensions: ["divina"]), .DiViNa)
        XCTAssertEqual(Format.of(mediaTypes: ["application/divina+zip"]), .DiViNa)
    }
    
    func testSniffHeavyDiViNa() {
        XCTAssertEqual(Format.of(fixtures.url(for: "divina-package.unknown")), .DiViNa)
    }
    
    func testSniffLightDiViNaManifest() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/divina+json"]), .DiViNaManifest)
    }
    
    func testSniffHeavyDiViNaManifest() {
        XCTAssertEqual(Format.of(fixtures.url(for: "divina.json")), .DiViNaManifest)
    }

    func testSniffLightEPUB() {
        XCTAssertEqual(Format.of(fileExtensions: ["epub"]), .EPUB)
        XCTAssertEqual(Format.of(mediaTypes: ["application/epub+zip"]), .EPUB)
    }
    
    func testSniffHeavyEPUB() {
        XCTAssertEqual(Format.of(fixtures.url(for: "epub.unknown")), .EPUB)
    }
    
    func testSniffLightGIF() {
        XCTAssertEqual(Format.of(fileExtensions: ["gif"]), .GIF)
        XCTAssertEqual(Format.of(mediaTypes: ["image/gif"]), .GIF)
    }
    
    func testSniffLightHTML() {
        XCTAssertEqual(Format.of(fileExtensions: ["htm"]), .HTML)
        XCTAssertEqual(Format.of(fileExtensions: ["html"]), .HTML)
        XCTAssertEqual(Format.of(fileExtensions: ["xht"]), .HTML)
        XCTAssertEqual(Format.of(fileExtensions: ["xhtml"]), .HTML)
        XCTAssertEqual(Format.of(mediaTypes: ["text/html"]), .HTML)
        XCTAssertEqual(Format.of(mediaTypes: ["application/xhtml+xml"]), .HTML)
    }
    
    func testSniffHeavyHTML() {
        XCTAssertEqual(Format.of(fixtures.url(for: "html.unknown")), .HTML)
        XCTAssertEqual(Format.of(fixtures.url(for: "xhtml.unknown")), .HTML)
    }
    
    func testSniffLightJPEG() {
        XCTAssertEqual(Format.of(fileExtensions: ["jpg"]), .JPEG)
        XCTAssertEqual(Format.of(fileExtensions: ["jpeg"]), .JPEG)
        XCTAssertEqual(Format.of(fileExtensions: ["jpe"]), .JPEG)
        XCTAssertEqual(Format.of(fileExtensions: ["jif"]), .JPEG)
        XCTAssertEqual(Format.of(fileExtensions: ["jfif"]), .JPEG)
        XCTAssertEqual(Format.of(fileExtensions: ["jfi"]), .JPEG)
        XCTAssertEqual(Format.of(mediaTypes: ["image/jpeg"]), .JPEG)
    }
    
    func testSniffLightOPDS1Feed() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/atom+xml;profile=opds-catalog"]), .OPDS1Feed)
    }
    
    func testSniffHeavyOPDS1Feed() {
        XCTAssertEqual(Format.of(fixtures.url(for: "opds1-feed.unknown")), .OPDS1Feed)
    }
    
    func testSniffLightOPDS1Entry() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/atom+xml;type=entry;profile=opds-catalog"]), .OPDS1Entry)
    }
    
    func testSniffHeavyOPDS1Entry() {
        XCTAssertEqual(Format.of(fixtures.url(for: "opds1-entry.unknown")), .OPDS1Entry)
    }
    
    func testSniffLightOPDS2Feed() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/opds+json"]), .OPDS2Feed)
    }
    
    func testSniffHeavyOPDS2Feed() {
        XCTAssertEqual(Format.of(fixtures.url(for: "opds2-feed.json")), .OPDS2Feed)
    }
    
    func testSniffLightOPDS2Publication() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/opds-publication+json"]), .OPDS2Publication)
    }
    
    func testSniffHeavyOPDS2Publication() {
        XCTAssertEqual(Format.of(fixtures.url(for: "opds2-publication.json")), .OPDS2Publication)
    }
    
    func testSniffLightLCPProtectedAudiobook() {
        XCTAssertEqual(Format.of(fileExtensions: ["lcpa"]), .LCPProtectedAudiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+lcp"]), .LCPProtectedAudiobook)
    }
    
    func testSniffHeavyLCPProtectedAudiobook() {
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook-lcp.unknown")), .LCPProtectedAudiobook)
    }
    
    func testSniffLightLCPProtectedPDF() {
        XCTAssertEqual(Format.of(fileExtensions: ["lcpdf"]), .LCPProtectedPDF)
        XCTAssertEqual(Format.of(mediaTypes: ["application/pdf+lcp"]), .LCPProtectedPDF)
    }
    
    func testSniffHeavyLCPProtectedPDF() {
        XCTAssertEqual(Format.of(fixtures.url(for: "pdf-lcp.unknown")), .LCPProtectedPDF)
    }
    
    func testSniffLightLCPLicenseDocument() {
        XCTAssertEqual(Format.of(fileExtensions: ["lcpl"]), .LCPLicense)
        XCTAssertEqual(Format.of(mediaTypes: ["application/vnd.readium.lcp.license.v1.0+json"]), .LCPLicense)
    }
    
    func testSniffHeavyLCPLicenseDocument() {
        XCTAssertEqual(Format.of(fixtures.url(for: "lcpl.unknown")), .LCPLicense)
    }
    
    func testSniffLightLPF() {
        XCTAssertEqual(Format.of(fileExtensions: ["lpf"]), .LPF)
        XCTAssertEqual(Format.of(mediaTypes: ["application/lpf+zip"]), .LPF)
    }
    
    func testSniffHeavyLPF() {
        XCTAssertEqual(Format.of(fixtures.url(for: "lpf.unknown")), .LPF)
        XCTAssertEqual(Format.of(fixtures.url(for: "lpf-index-html.unknown")), .LPF)
    }
    
    func testSniffLightPDF() {
        XCTAssertEqual(Format.of(fileExtensions: ["pdf"]), .PDF)
        XCTAssertEqual(Format.of(mediaTypes: ["application/pdf"]), .PDF)
    }
    
    func testSniffHeavyPDF() {
        XCTAssertEqual(Format.of(fixtures.url(for: "pdf.unknown")), .PDF)
    }
    
    func testSniffLightPNG() {
        XCTAssertEqual(Format.of(fileExtensions: ["png"]), .PNG)
        XCTAssertEqual(Format.of(mediaTypes: ["image/png"]), .PNG)
    }
    
    func testSniffLightTIFF() {
        XCTAssertEqual(Format.of(fileExtensions: ["tiff"]), .TIFF)
        XCTAssertEqual(Format.of(fileExtensions: ["tif"]), .TIFF)
        XCTAssertEqual(Format.of(mediaTypes: ["image/tiff"]), .TIFF)
        XCTAssertEqual(Format.of(mediaTypes: ["image/tiff-fx"]), .TIFF)
    }
    
    func testSniffLightWebP() {
        XCTAssertEqual(Format.of(fileExtensions: ["webp"]), .WebP)
        XCTAssertEqual(Format.of(mediaTypes: ["image/webp"]), .WebP)
    }

    func testSniffLightWebPub() {
        XCTAssertEqual(Format.of(fileExtensions: ["webpub"]), .WebPub)
        XCTAssertEqual(Format.of(mediaTypes: ["application/webpub+zip"]), .WebPub)
    }
    
    func testSniffHeavyWebPub() {
        XCTAssertEqual(Format.of(fixtures.url(for: "webpub-package.unknown")), .WebPub)
    }
    
    func testSniffLightWebPubManifest() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/webpub+json"]), .WebPubManifest)
    }
    
    func testSniffHeavyWebPubManifest() {
        XCTAssertEqual(Format.of(fixtures.url(for: "webpub.json")), .WebPubManifest)
    }
    
    func testSniffHeavyW3CWPUBManifest() {
        XCTAssertEqual(Format.of(fixtures.url(for: "w3c-wpub.json")), .W3CWPUBManifest)
    }
    
    func testSniffLightZAB() {
        XCTAssertEqual(Format.of(fileExtensions: ["zab"]), .ZAB)
    }
    
    func testSniffHeavyZAB() {
        XCTAssertEqual(Format.of(fixtures.url(for: "zab.unknown")), .ZAB)
    }

}
