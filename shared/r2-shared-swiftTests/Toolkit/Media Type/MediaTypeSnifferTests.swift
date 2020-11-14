//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
@testable import R2Shared

class MediaTypeSnifferTests: XCTestCase {

    let fixtures = Fixtures(path: "Format")
    
    func testSniffIgnoresExtensionCase() {
        XCTAssertEqual(MediaType.of(fileExtension: "EPUB"), .epub)
    }
    
    func testSniffIgnoresMediaTypeCase() {
        XCTAssertEqual(MediaType.of(mediaType: "APPLICATION/EPUB+ZIP"), .epub)
    }
    
    func testSniffIgnoresMediaTypeExtraParameters() {
        XCTAssertEqual(MediaType.of(mediaType: "application/epub+zip;param=value"), .epub)
    }

    func testSniffFallbackOnParse() {
        let expected = MediaType("fruit/grapes")!
        XCTAssertEqual(MediaType.of(mediaType: "fruit/grapes"), expected)
        XCTAssertEqual(MediaType.of(mediaType: "fruit/grapes"), expected)
        XCTAssertEqual(MediaType.of(mediaTypes: ["invalid", "fruit/grapes"], fileExtensions: []), expected)
        XCTAssertEqual(MediaType.of(mediaTypes: ["fruit/grapes", "vegetable/brocoli"], fileExtensions: []), expected)

    }
    
    func testSniffFromMetadata() {
        XCTAssertNil(MediaType.of(fileExtension: nil))
        XCTAssertEqual(MediaType.of(fileExtension: "audiobook"), .readiumAudiobook)
        XCTAssertNil(MediaType.of(mediaType: nil))
        XCTAssertEqual(MediaType.of(mediaType: "application/audiobook+zip"), .readiumAudiobook)
        XCTAssertEqual(MediaType.of(mediaType: "application/audiobook+zip"), .readiumAudiobook)
        XCTAssertEqual(MediaType.of(mediaType: "application/audiobook+zip", fileExtension: "audiobook"), .readiumAudiobook)
        XCTAssertEqual(MediaType.of(mediaTypes: ["application/audiobook+zip"], fileExtensions: ["audiobook"]), .readiumAudiobook)
    }
    
    func testSniffFromAFile() {
        XCTAssertEqual(MediaType.of(fixtures.url(for: "audiobook.json")), .readiumAudiobookManifest)
    }
    
    func testSniffFromBytes() {
        let data = try! Data(contentsOf: fixtures.url(for: "audiobook.json"))
        XCTAssertEqual(MediaType.of({ data }), .readiumAudiobookManifest)
    }

    func testSniffUnknownMediaType() {
        XCTAssertNil(MediaType.of(mediaType: "unknown"))
        XCTAssertNil(MediaType.of(fixtures.url(for: "unknown")))
    }
    
    func testSniffAudiobook() {
        XCTAssertEqual(MediaType.of(fileExtension: "audiobook"), .readiumAudiobook)
        XCTAssertEqual(MediaType.of(mediaType: "application/audiobook+zip"), .readiumAudiobook)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "audiobook-package.unknown")), .readiumAudiobook)
    }
    
    func testSniffAudiobookManifest() {
        XCTAssertEqual(MediaType.of(mediaType: "application/audiobook+json"), .readiumAudiobookManifest)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "audiobook.json")), .readiumAudiobookManifest)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "audiobook-wrongtype.json")), .readiumAudiobookManifest)
    }
    
    func testSniffBMP() {
        XCTAssertEqual(MediaType.of(fileExtension: "bmp"), .bmp)
        XCTAssertEqual(MediaType.of(fileExtension: "dib"), .bmp)
        XCTAssertEqual(MediaType.of(mediaType: "image/bmp"), .bmp)
        XCTAssertEqual(MediaType.of(mediaType: "image/x-bmp"), .bmp)
    }
    
    func testSniffCBZ() {
        XCTAssertEqual(MediaType.of(fileExtension: "cbz"), .cbz)
        XCTAssertEqual(MediaType.of(mediaType: "application/vnd.comicbook+zip"), .cbz)
        XCTAssertEqual(MediaType.of(mediaType: "application/x-cbz"), .cbz)
        XCTAssertEqual(MediaType.of(mediaType: "application/x-cbr"), .cbz)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "cbz.unknown")), .cbz)
    }
    
    func testSniffDiViNa() {
        XCTAssertEqual(MediaType.of(fileExtension: "divina"), .divina)
        XCTAssertEqual(MediaType.of(mediaType: "application/divina+zip"), .divina)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "divina-package.unknown")), .divina)
    }
    
    func testSniffDiViNaManifest() {
        XCTAssertEqual(MediaType.of(mediaType: "application/divina+json"), .divinaManifest)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "divina.json")), .divinaManifest)
    }

    func testSniffEPUB() {
        XCTAssertEqual(MediaType.of(fileExtension: "epub"), .epub)
        XCTAssertEqual(MediaType.of(mediaType: "application/epub+zip"), .epub)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "epub.unknown")), .epub)
    }
    
    func testSniffGIF() {
        XCTAssertEqual(MediaType.of(fileExtension: "gif"), .gif)
        XCTAssertEqual(MediaType.of(mediaType: "image/gif"), .gif)
    }
    
    func testSniffHTML() {
        XCTAssertEqual(MediaType.of(fileExtension: "htm"), .html)
        XCTAssertEqual(MediaType.of(fileExtension: "html"), .html)
        XCTAssertEqual(MediaType.of(fileExtension: "xht"), .html)
        XCTAssertEqual(MediaType.of(fileExtension: "xhtml"), .html)
        XCTAssertEqual(MediaType.of(mediaType: "text/html"), .html)
        XCTAssertEqual(MediaType.of(mediaType: "application/xhtml+xml"), .html)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "html.unknown")), .html)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "xhtml.unknown")), .html)
    }
    
    func testSniffJPEG() {
        XCTAssertEqual(MediaType.of(fileExtension: "jpg"), .jpeg)
        XCTAssertEqual(MediaType.of(fileExtension: "jpeg"), .jpeg)
        XCTAssertEqual(MediaType.of(fileExtension: "jpe"), .jpeg)
        XCTAssertEqual(MediaType.of(fileExtension: "jif"), .jpeg)
        XCTAssertEqual(MediaType.of(fileExtension: "jfif"), .jpeg)
        XCTAssertEqual(MediaType.of(fileExtension: "jfi"), .jpeg)
        XCTAssertEqual(MediaType.of(mediaType: "image/jpeg"), .jpeg)
    }
    
    func testSniffOPDS1Feed() {
        XCTAssertEqual(MediaType.of(mediaType: "application/atom+xml;profile=opds-catalog"), .opds1)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "opds1-feed.unknown")), .opds1)
    }
    
    func testSniffOPDS1Entry() {
        XCTAssertEqual(MediaType.of(mediaType: "application/atom+xml;type=entry;profile=opds-catalog"), .opds1Entry)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "opds1-entry.unknown")), .opds1Entry)
    }
    
    func testSniffOPDS2Feed() {
        XCTAssertEqual(MediaType.of(mediaType: "application/opds+json"), .opds2)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "opds2-feed.json")), .opds2)
    }
    
    func testSniffOPDS2Publication() {
        XCTAssertEqual(MediaType.of(mediaType: "application/opds-publication+json"), .opds2Publication)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "opds2-publication.json")), .opds2Publication)
    }
    
    func testSniffOPDSAuthentication() {
        XCTAssertEqual(MediaType.of(mediaType: "application/opds-authentication+json"), .opdsAuthentication)
        XCTAssertEqual(MediaType.of(mediaType: "application/vnd.opds.authentication.v1.0+json"), .opdsAuthentication)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "opds-authentication.json")), .opdsAuthentication)
    }
    
    func testSniffLCPProtectedAudiobook() {
        XCTAssertEqual(MediaType.of(fileExtension: "lcpa"), .lcpProtectedAudiobook)
        XCTAssertEqual(MediaType.of(mediaType: "application/audiobook+lcp"), .lcpProtectedAudiobook)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "audiobook-lcp.unknown")), .lcpProtectedAudiobook)
    }
    
    func testSniffLCPProtectedPDF() {
        XCTAssertEqual(MediaType.of(fileExtension: "lcpdf"), .lcpProtectedPDF)
        XCTAssertEqual(MediaType.of(mediaType: "application/pdf+lcp"), .lcpProtectedPDF)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "pdf-lcp.unknown")), .lcpProtectedPDF)
    }
    
    func testSniffLCPLicenseDocument() {
        XCTAssertEqual(MediaType.of(fileExtension: "lcpl"), .lcpLicenseDocument)
        XCTAssertEqual(MediaType.of(mediaType: "application/vnd.readium.lcp.license.v1.0+json"), .lcpLicenseDocument)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "lcpl.unknown")), .lcpLicenseDocument)
    }
    
    func testSniffLPF() {
        XCTAssertEqual(MediaType.of(fileExtension: "lpf"), .lpf)
        XCTAssertEqual(MediaType.of(mediaType: "application/lpf+zip"), .lpf)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "lpf.unknown")), .lpf)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "lpf-index-html.unknown")), .lpf)
    }
    
    func testSniffPDF() {
        XCTAssertEqual(MediaType.of(fileExtension: "pdf"), .pdf)
        XCTAssertEqual(MediaType.of(mediaType: "application/pdf"), .pdf)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "pdf.unknown")), .pdf)
    }
    
    func testSniffPNG() {
        XCTAssertEqual(MediaType.of(fileExtension: "png"), .png)
        XCTAssertEqual(MediaType.of(mediaType: "image/png"), .png)
    }
    
    func testSniffTIFF() {
        XCTAssertEqual(MediaType.of(fileExtension: "tiff"), .tiff)
        XCTAssertEqual(MediaType.of(fileExtension: "tif"), .tiff)
        XCTAssertEqual(MediaType.of(mediaType: "image/tiff"), .tiff)
        XCTAssertEqual(MediaType.of(mediaType: "image/tiff-fx"), .tiff)
    }
    
    func testSniffWebP() {
        XCTAssertEqual(MediaType.of(fileExtension: "webp"), .webp)
        XCTAssertEqual(MediaType.of(mediaType: "image/webp"), .webp)
    }

    func testSniffWebPub() {
        XCTAssertEqual(MediaType.of(fileExtension: "webpub"), .readiumWebPub)
        XCTAssertEqual(MediaType.of(mediaType: "application/webpub+zip"), .readiumWebPub)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "webpub-package.unknown")), .readiumWebPub)
    }
    
    func testSniffWebPubManifest() {
        XCTAssertEqual(MediaType.of(mediaType: "application/webpub+json"), .readiumWebPubManifest)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "webpub.json")), .readiumWebPubManifest)
    }
    
    func testSniffW3CWPUBManifest() {
        XCTAssertEqual(MediaType.of(fixtures.url(for: "w3c-wpub.json")), .w3cWPUBManifest)
    }
    
    func testSniffZAB() {
        XCTAssertEqual(MediaType.of(fileExtension: "zab"), .zab)
        XCTAssertEqual(MediaType.of(fixtures.url(for: "zab.unknown")), .zab)
    }
    
    func testSniffSystemUTI() {
        let css = MediaType("text/css", name: "CSS", fileExtension: "css")
        XCTAssertEqual(MediaType.of(fileExtension: "css"), css)
        XCTAssertEqual(MediaType.of(mediaType: "text/css"), css)
        
        let xlsx = MediaType(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            name: "Office Open XML spreadsheet",
            fileExtension: "xlsx"
        )
        XCTAssertEqual(MediaType.of(fileExtension: "xlsx"), xlsx)
        XCTAssertEqual(MediaType.of(mediaType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"), xlsx)
    }

}
