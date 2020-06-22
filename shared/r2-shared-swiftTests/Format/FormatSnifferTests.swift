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
        XCTAssertEqual(Format.of(fileExtension: "EPUB"), .epub)
    }
    
    func testSniffIgnoresMediaTypeCase() {
        XCTAssertEqual(Format.of(mediaType: "APPLICATION/EPUB+ZIP"), .epub)
    }
    
    func testSniffIgnoresMediaTypeExtraParameters() {
        XCTAssertEqual(Format.of(mediaType: "application/epub+zip;param=value"), .epub)
    }
    
    func testSniffFromMetadata() {
        XCTAssertNil(Format.of(fileExtension: nil))
        XCTAssertEqual(Format.of(fileExtension: "audiobook"), .readiumAudiobook)
        XCTAssertNil(Format.of(mediaType: nil))
        XCTAssertEqual(Format.of(mediaType: "application/audiobook+zip"), .readiumAudiobook)
        XCTAssertEqual(Format.of(mediaType: "application/audiobook+zip"), .readiumAudiobook)
        XCTAssertEqual(Format.of(mediaType: "application/audiobook+zip", fileExtension: "audiobook"), .readiumAudiobook)
        XCTAssertEqual(Format.of(mediaTypes: ["application/audiobook+zip"], fileExtensions: ["audiobook"]), .readiumAudiobook)
    }
    
    func testSniffFromAFile() {
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook.json")), .readiumAudiobookManifest)
    }
    
    func testSniffFromBytes() {
        let data = try! Data(contentsOf: fixtures.url(for: "audiobook.json"))
        XCTAssertEqual(Format.of({ data }), .readiumAudiobookManifest)
    }

    func testSniffUnknownFormat() {
        XCTAssertNil(Format.of(mediaType: "unknown/type"))
        XCTAssertNil(Format.of(fixtures.url(for: "unknown")))
    }
    
    func testSniffAudiobook() {
        XCTAssertEqual(Format.of(fileExtension: "audiobook"), .readiumAudiobook)
        XCTAssertEqual(Format.of(mediaType: "application/audiobook+zip"), .readiumAudiobook)
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook-package.unknown")), .readiumAudiobook)
    }
    
    func testSniffAudiobookManifest() {
        XCTAssertEqual(Format.of(mediaType: "application/audiobook+json"), .readiumAudiobookManifest)
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook.json")), .readiumAudiobookManifest)
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook-wrongtype.json")), .readiumAudiobookManifest)
    }
    
    func testSniffBMP() {
        XCTAssertEqual(Format.of(fileExtension: "bmp"), .bmp)
        XCTAssertEqual(Format.of(fileExtension: "dib"), .bmp)
        XCTAssertEqual(Format.of(mediaType: "image/bmp"), .bmp)
        XCTAssertEqual(Format.of(mediaType: "image/x-bmp"), .bmp)
    }
    
    func testSniffCBZ() {
        XCTAssertEqual(Format.of(fileExtension: "cbz"), .cbz)
        XCTAssertEqual(Format.of(mediaType: "application/vnd.comicbook+zip"), .cbz)
        XCTAssertEqual(Format.of(mediaType: "application/x-cbz"), .cbz)
        XCTAssertEqual(Format.of(mediaType: "application/x-cbr"), .cbz)
        XCTAssertEqual(Format.of(fixtures.url(for: "cbz.unknown")), .cbz)
    }
    
    func testSniffDiViNa() {
        XCTAssertEqual(Format.of(fileExtension: "divina"), .divina)
        XCTAssertEqual(Format.of(mediaType: "application/divina+zip"), .divina)
        XCTAssertEqual(Format.of(fixtures.url(for: "divina-package.unknown")), .divina)
    }
    
    func testSniffDiViNaManifest() {
        XCTAssertEqual(Format.of(mediaType: "application/divina+json"), .divinaManifest)
        XCTAssertEqual(Format.of(fixtures.url(for: "divina.json")), .divinaManifest)
    }

    func testSniffEPUB() {
        XCTAssertEqual(Format.of(fileExtension: "epub"), .epub)
        XCTAssertEqual(Format.of(mediaType: "application/epub+zip"), .epub)
        XCTAssertEqual(Format.of(fixtures.url(for: "epub.unknown")), .epub)
    }
    
    func testSniffGIF() {
        XCTAssertEqual(Format.of(fileExtension: "gif"), .gif)
        XCTAssertEqual(Format.of(mediaType: "image/gif"), .gif)
    }
    
    func testSniffHTML() {
        XCTAssertEqual(Format.of(fileExtension: "htm"), .html)
        XCTAssertEqual(Format.of(fileExtension: "html"), .html)
        XCTAssertEqual(Format.of(fileExtension: "xht"), .html)
        XCTAssertEqual(Format.of(fileExtension: "xhtml"), .html)
        XCTAssertEqual(Format.of(mediaType: "text/html"), .html)
        XCTAssertEqual(Format.of(mediaType: "application/xhtml+xml"), .html)
        XCTAssertEqual(Format.of(fixtures.url(for: "html.unknown")), .html)
        XCTAssertEqual(Format.of(fixtures.url(for: "xhtml.unknown")), .html)
    }
    
    func testSniffJPEG() {
        XCTAssertEqual(Format.of(fileExtension: "jpg"), .jpeg)
        XCTAssertEqual(Format.of(fileExtension: "jpeg"), .jpeg)
        XCTAssertEqual(Format.of(fileExtension: "jpe"), .jpeg)
        XCTAssertEqual(Format.of(fileExtension: "jif"), .jpeg)
        XCTAssertEqual(Format.of(fileExtension: "jfif"), .jpeg)
        XCTAssertEqual(Format.of(fileExtension: "jfi"), .jpeg)
        XCTAssertEqual(Format.of(mediaType: "image/jpeg"), .jpeg)
    }
    
    func testSniffOPDS1Feed() {
        XCTAssertEqual(Format.of(mediaType: "application/atom+xml;profile=opds-catalog"), .opds1Feed)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds1-feed.unknown")), .opds1Feed)
    }
    
    func testSniffOPDS1Entry() {
        XCTAssertEqual(Format.of(mediaType: "application/atom+xml;type=entry;profile=opds-catalog"), .opds1Entry)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds1-entry.unknown")), .opds1Entry)
    }
    
    func testSniffOPDS2Feed() {
        XCTAssertEqual(Format.of(mediaType: "application/opds+json"), .opds2Feed)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds2-feed.json")), .opds2Feed)
    }
    
    func testSniffOPDS2Publication() {
        XCTAssertEqual(Format.of(mediaType: "application/opds-publication+json"), .opds2Publication)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds2-publication.json")), .opds2Publication)
    }
    
    func testSniffOPDSAuthentication() {
        XCTAssertEqual(Format.of(mediaType: "application/opds-authentication+json"), .opdsAuthentication)
        XCTAssertEqual(Format.of(mediaType: "application/vnd.opds.authentication.v1.0+json"), .opdsAuthentication)
        XCTAssertEqual(Format.of(fixtures.url(for: "opds-authentication.json")), .opdsAuthentication)
    }
    
    func testSniffLCPProtectedAudiobook() {
        XCTAssertEqual(Format.of(fileExtension: "lcpa"), .lcpProtectedAudiobook)
        XCTAssertEqual(Format.of(mediaType: "application/audiobook+lcp"), .lcpProtectedAudiobook)
        XCTAssertEqual(Format.of(fixtures.url(for: "audiobook-lcp.unknown")), .lcpProtectedAudiobook)
    }
    
    func testSniffLCPProtectedPDF() {
        XCTAssertEqual(Format.of(fileExtension: "lcpdf"), .lcpProtectedPDF)
        XCTAssertEqual(Format.of(mediaType: "application/pdf+lcp"), .lcpProtectedPDF)
        XCTAssertEqual(Format.of(fixtures.url(for: "pdf-lcp.unknown")), .lcpProtectedPDF)
    }
    
    func testSniffLCPLicenseDocument() {
        XCTAssertEqual(Format.of(fileExtension: "lcpl"), .lcpLicense)
        XCTAssertEqual(Format.of(mediaType: "application/vnd.readium.lcp.license.v1.0+json"), .lcpLicense)
        XCTAssertEqual(Format.of(fixtures.url(for: "lcpl.unknown")), .lcpLicense)
    }
    
    func testSniffLPF() {
        XCTAssertEqual(Format.of(fileExtension: "lpf"), .lpf)
        XCTAssertEqual(Format.of(mediaType: "application/lpf+zip"), .lpf)
        XCTAssertEqual(Format.of(fixtures.url(for: "lpf.unknown")), .lpf)
        XCTAssertEqual(Format.of(fixtures.url(for: "lpf-index-html.unknown")), .lpf)
    }
    
    func testSniffPDF() {
        XCTAssertEqual(Format.of(fileExtension: "pdf"), .pdf)
        XCTAssertEqual(Format.of(mediaType: "application/pdf"), .pdf)
        XCTAssertEqual(Format.of(fixtures.url(for: "pdf.unknown")), .pdf)
    }
    
    func testSniffPNG() {
        XCTAssertEqual(Format.of(fileExtension: "png"), .png)
        XCTAssertEqual(Format.of(mediaType: "image/png"), .png)
    }
    
    func testSniffTIFF() {
        XCTAssertEqual(Format.of(fileExtension: "tiff"), .tiff)
        XCTAssertEqual(Format.of(fileExtension: "tif"), .tiff)
        XCTAssertEqual(Format.of(mediaType: "image/tiff"), .tiff)
        XCTAssertEqual(Format.of(mediaType: "image/tiff-fx"), .tiff)
    }
    
    func testSniffWebP() {
        XCTAssertEqual(Format.of(fileExtension: "webp"), .webp)
        XCTAssertEqual(Format.of(mediaType: "image/webp"), .webp)
    }

    func testSniffWebPub() {
        XCTAssertEqual(Format.of(fileExtension: "webpub"), .readiumWebPub)
        XCTAssertEqual(Format.of(mediaType: "application/webpub+zip"), .readiumWebPub)
        XCTAssertEqual(Format.of(fixtures.url(for: "webpub-package.unknown")), .readiumWebPub)
    }
    
    func testSniffWebPubManifest() {
        XCTAssertEqual(Format.of(mediaType: "application/webpub+json"), .readiumWebPubManifest)
        XCTAssertEqual(Format.of(fixtures.url(for: "webpub.json")), .readiumWebPubManifest)
    }
    
    func testSniffW3CWPUBManifest() {
        XCTAssertEqual(Format.of(fixtures.url(for: "w3c-wpub.json")), .w3cWPUBManifest)
    }
    
    func testSniffZAB() {
        XCTAssertEqual(Format.of(fileExtension: "zab"), .zab)
        XCTAssertEqual(Format.of(fixtures.url(for: "zab.unknown")), .zab)
    }
    
    func testSniffSystemUTI() {
        let css = Format(name: "CSS", mediaType: MediaType("text/css")!, fileExtension: "css")
        XCTAssertEqual(Format.of(fileExtension: "css"), css)
        XCTAssertEqual(Format.of(mediaType: "text/css"), css)
        
        let xlsx = Format(
            name: "Office Open XML spreadsheet",
            mediaType: MediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")!,
            fileExtension: "xlsx"
        )
        XCTAssertEqual(Format.of(fileExtension: "xlsx"), xlsx)
        XCTAssertEqual(Format.of(mediaType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"), xlsx)
    }

}
