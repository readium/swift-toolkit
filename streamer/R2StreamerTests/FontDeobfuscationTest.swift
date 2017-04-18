//
//  DecoderTest.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/18/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest
@testable import R2Streamer

class DecoderTest: XCTestCase {
    var testFontBytes: [UInt8]!
    var testPublication: Publication!
    var obfuscatedFontStream: SeekableInputStream!

    override func setUp() {
        super.setUp()
        let sg = SampleGenerator()

        // Setup test publication.
        testPublication = Publication()
        testPublication.metadata.identifier = "urn:uuid:36d5078e-ff7d-468e-a5f3-f47c14b91f2f"
        // Setup the testFontBytes.
        guard let testFontUrl = sg.getSamplesUrl(named: "SmokeTestFXL/fonts/cut-cut.woff", ofType: ".woff"),
            let testFontData = try? Data(contentsOf: testFontUrl) else
        {
            XCTFail("Couldn't open the clear font file.")
            return
        }
        testFontBytes = testFontData.bytes
        // Setup obfuscated font seekable input stream.
        guard let epubArchiveUrl = sg.getSamplesUrl(named: "SmokeTestFXL", ofType: ".epub"),
            let zipArchive = ZipArchive(url: epubArchiveUrl) else {
            XCTFail("Couldn't instanciate the .epub obfuscated font archive url")
        }


        obfuscatedFontStream = ZipInputStream(zipArchive: zipArchive, path: "fonts/cut-cut.obf.woff")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        let decoder = Decoder()
        let testFontStream =
        let fontBytes = decoder.decode(<#T##input: SeekableInputStream##SeekableInputStream#>, of: <#T##Publication#>, at: <#T##String#>)

    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
