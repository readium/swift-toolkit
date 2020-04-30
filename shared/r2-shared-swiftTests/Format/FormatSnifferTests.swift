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
        XCTAssertEqual(Format.of(fileExtensions: ["EPUB"]), .epub)
    }
    
    func testSniffIgnoresMediaTypeCase() {
        XCTAssertEqual(Format.of(mediaTypes: ["APPLICATION/EPUB+ZIP"]), .epub)
    }
    
    func testSniffIgnoresMediaTypeExtraParameters() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/epub+zip;param=value"]), .epub)
    }
    
    func testSniffFromMetadata() {
        XCTAssertEqual(Format.of(fileExtensions: ["audiobook"]), .audiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+zip"]), .audiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+zip"], fileExtensions: ["audiobook"]), .audiobook)
    }
    
    func testSniffFromAFile() {
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook.json")), .audiobookManifest)
    }
    
    func testSniffFromBytes() {
        let data = try! Data(contentsOf: fixtures.url(for: "audiobook.json"))
        XCTAssertEqual(Format.of({ data }), .audiobookManifest)
    }

    func testSniffUnknownFormat() {
        XCTAssertNil(Format.of(mediaTypes: ["unknown/type"]))
        XCTAssertNil(Format.of(fixtures.url(for: "unknown")))
    }
    
    func testSniffAudiobook() {
        XCTAssertEqual(Format.of(fileExtensions: ["audiobook"]), .audiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+zip"]), .audiobook)
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook-package.unknown")), .audiobook)
    }
    
    func testSniffAudiobookManifest() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+json"]), .audiobookManifest)
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook.json")), .audiobookManifest)
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook-wrongtype.json")), .audiobookManifest)
    }
    
    func testSniffBMP() {
        XCTAssertEqual(Format.of(fileExtensions: ["bmp"]), .bmp)
        XCTAssertEqual(Format.of(fileExtensions: ["dib"]), .bmp)
        XCTAssertEqual(Format.of(mediaTypes: ["image/bmp"]), .bmp)
        XCTAssertEqual(Format.of(mediaTypes: ["image/x-bmp"]), .bmp)
    }
    
    func testSniffCBZ() {
        XCTAssertEqual(Format.of(fileExtensions: ["cbz"]), .cbz)
        XCTAssertEqual(Format.of(mediaTypes: ["application/vnd.comicbook+zip"]), .cbz)
        XCTAssertEqual(Format.of(mediaTypes: ["application/x-cbz"]), .cbz)
        XCTAssertEqual(Format.of(mediaTypes: ["application/x-cbr"]), .cbz)
        XCTAssertEqual(Format.of(fixtures.url(for: "cbz.unknown")), .cbz)
    }
    
    func testSniffDiViNa() {
        XCTAssertEqual(Format.of(fileExtensions: ["divina"]), .divina)
        XCTAssertEqual(Format.of(mediaTypes: ["application/divina+zip"]), .divina)
        XCTAssertEqual(Format.of(fixtures.url(for: "divina-package.unknown")), .divina)
    }
    
    func testSniffDiViNaManifest() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/divina+json"]), .divinaManifest)
        XCTAssertEqual(Format.of(fixtures.url(for: "divina.json")), .divinaManifest)
    }

    func testSniffEPUB() {
        XCTAssertEqual(Format.of(fileExtensions: ["epub"]), .epub)
        XCTAssertEqual(Format.of(mediaTypes: ["application/epub+zip"]), .epub)
        XCTAssertEqual(Format.of(fixtures.url(for: "epub.unknown")), .epub)
    }
    
    func testSniffGIF() {
        XCTAssertEqual(Format.of(fileExtensions: ["gif"]), .gif)
        XCTAssertEqual(Format.of(mediaTypes: ["image/gif"]), .gif)
    }
    
    func testSniffHTML() {
        XCTAssertEqual(Format.of(fileExtensions: ["htm"]), .html)
        XCTAssertEqual(Format.of(fileExtensions: ["html"]), .html)
        XCTAssertEqual(Format.of(fileExtensions: ["xht"]), .html)
        XCTAssertEqual(Format.of(fileExtensions: ["xhtml"]), .html)
        XCTAssertEqual(Format.of(mediaTypes: ["text/html"]), .html)
        XCTAssertEqual(Format.of(mediaTypes: ["application/xhtml+xml"]), .html)
        XCTAssertEqual(Format.of(fixtures.url(for: "html.unknown")), .html)
        XCTAssertEqual(Format.of(fixtures.url(for: "xhtml.unknown")), .html)
    }
    
    func testSniffJPEG() {
        XCTAssertEqual(Format.of(fileExtensions: ["jpg"]), .jpeg)
        XCTAssertEqual(Format.of(fileExtensions: ["jpeg"]), .jpeg)
        XCTAssertEqual(Format.of(fileExtensions: ["jpe"]), .jpeg)
        XCTAssertEqual(Format.of(fileExtensions: ["jif"]), .jpeg)
        XCTAssertEqual(Format.of(fileExtensions: ["jfif"]), .jpeg)
        XCTAssertEqual(Format.of(fileExtensions: ["jfi"]), .jpeg)
        XCTAssertEqual(Format.of(mediaTypes: ["image/jpeg"]), .jpeg)
    }
    
    func testSniffOPDS1Feed() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/atom+xml;profile=opds-catalog"]), .opds1Feed)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds1-feed.unknown")), .opds1Feed)
    }
    
    func testSniffOPDS1Entry() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/atom+xml;type=entry;profile=opds-catalog"]), .opds1Entry)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds1-entry.unknown")), .opds1Entry)
    }
    
    func testSniffOPDS2Feed() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/opds+json"]), .opds2Feed)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds2-feed.json")), .opds2Feed)
    }
    
    func testSniffOPDS2Publication() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/opds-publication+json"]), .opds2Publication)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds2-publication.json")), .opds2Publication)
    }
    
    func testSniffLCPProtectedAudiobook() {
        XCTAssertEqual(Format.of(fileExtensions: ["lcpa"]), .lcpProtectedAudiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+lcp"]), .lcpProtectedAudiobook)
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook-lcp.unknown")), .lcpProtectedAudiobook)
    }
    
    func testSniffLCPProtectedPDF() {
        XCTAssertEqual(Format.of(fileExtensions: ["lcpdf"]), .lcpProtectedPDF)
        XCTAssertEqual(Format.of(mediaTypes: ["application/pdf+lcp"]), .lcpProtectedPDF)
        XCTAssertEqual(Format.of(fixtures.url(for: "pdf-lcp.unknown")), .lcpProtectedPDF)
    }
    
    func testSniffLCPLicenseDocument() {
        XCTAssertEqual(Format.of(fileExtensions: ["lcpl"]), .lcpLicense)
        XCTAssertEqual(Format.of(mediaTypes: ["application/vnd.readium.lcp.license.v1.0+json"]), .lcpLicense)
        XCTAssertEqual(Format.of(fixtures.url(for: "lcpl.unknown")), .lcpLicense)
    }
    
    func testSniffLPF() {
        XCTAssertEqual(Format.of(fileExtensions: ["lpf"]), .lpf)
        XCTAssertEqual(Format.of(mediaTypes: ["application/lpf+zip"]), .lpf)
        XCTAssertEqual(Format.of(fixtures.url(for: "lpf.unknown")), .lpf)
        XCTAssertEqual(Format.of(fixtures.url(for: "lpf-index-html.unknown")), .lpf)
    }
    
    func testSniffPDF() {
        XCTAssertEqual(Format.of(fileExtensions: ["pdf"]), .pdf)
        XCTAssertEqual(Format.of(mediaTypes: ["application/pdf"]), .pdf)
        XCTAssertEqual(Format.of(fixtures.url(for: "pdf.unknown")), .pdf)
    }
    
    func testSniffPNG() {
        XCTAssertEqual(Format.of(fileExtensions: ["png"]), .png)
        XCTAssertEqual(Format.of(mediaTypes: ["image/png"]), .png)
    }
    
    func testSniffTIFF() {
        XCTAssertEqual(Format.of(fileExtensions: ["tiff"]), .tiff)
        XCTAssertEqual(Format.of(fileExtensions: ["tif"]), .tiff)
        XCTAssertEqual(Format.of(mediaTypes: ["image/tiff"]), .tiff)
        XCTAssertEqual(Format.of(mediaTypes: ["image/tiff-fx"]), .tiff)
    }
    
    func testSniffWebP() {
        XCTAssertEqual(Format.of(fileExtensions: ["webp"]), .webp)
        XCTAssertEqual(Format.of(mediaTypes: ["image/webp"]), .webp)
    }

    func testSniffWebPub() {
        XCTAssertEqual(Format.of(fileExtensions: ["webpub"]), .webpub)
        XCTAssertEqual(Format.of(mediaTypes: ["application/webpub+zip"]), .webpub)
        XCTAssertEqual(Format.of(fixtures.url(for: "webpub-package.unknown")), .webpub)
    }
    
    func testSniffWebPubManifest() {
        XCTAssertEqual(Format.of(mediaTypes: ["application/webpub+json"]), .webpubManifest)
        XCTAssertEqual(Format.of(fixtures.url(for: "webpub.json")), .webpubManifest)
    }
    
    func testSniffW3CWPUBManifest() {
        XCTAssertEqual(Format.of(fixtures.url(for: "w3c-wpub.json")), .w3cWPUBManifest)
    }
    
    func testSniffZAB() {
        XCTAssertEqual(Format.of(fileExtensions: ["zab"]), .zab)
        XCTAssertEqual(Format.of(fixtures.url(for: "zab.unknown")), .zab)
    }
    
    func testSniffSystemUTI() {
        let css = Format(name: "CSS", mediaType: MediaType("text/css")!, fileExtension: "css")
        XCTAssertEqual(Format.of(fileExtensions: ["css"]), css)
        XCTAssertEqual(Format.of(mediaTypes: ["text/css"]), css)
        
        let xlsx = Format(
            name: "Office Open XML spreadsheet",
            mediaType: MediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")!,
            fileExtension: "xlsx"
        )
        XCTAssertEqual(Format.of(fileExtensions: ["xlsx"]), xlsx)
        XCTAssertEqual(Format.of(mediaTypes: ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]), xlsx)
    }

}
