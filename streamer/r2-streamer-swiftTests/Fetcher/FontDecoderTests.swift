//
//  FontDecoderTest.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/18/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import XCTest
import R2Shared
@testable import R2Streamer

class FontDecoderTests: XCTestCase {
    var testPublication: Publication!
    var testFontBytes: [UInt8]!
    var obfuscatedFontStreamIdpf: SeekableInputStream!
    var obfuscatedFontStreamAdobe: SeekableInputStream!

    override func setUp() {
        super.setUp()
        let sg = SampleGenerator()

        // Setup test publication.
        testPublication = Publication(
            metadata: Metadata(
                identifier: "urn:uuid:36d5078e-ff7d-468e-a5f3-f47c14b91f2f",
                title: "Title"
            )
        )
        // Setup the testFontBytes.
        guard var testFontUrl = sg.getSamplesUrl(named: "SmokeTestFXL/fonts/cut-cut", ofType: ".woff") else {
            XCTFail("Couldn't generate the test font URL.")
            return
        }
        testFontUrl = URL(string: "file://\(testFontUrl.absoluteString)")!
        guard let testFontData = try? Data(contentsOf: testFontUrl) else {
            XCTFail("Couldn't get the data from the test font file at \(testFontUrl).")
            return
        }
        testFontBytes = testFontData.bytes

        // Setup obfuscated font seekable input stream.
        guard let epubArchiveUrl = sg.getSamplesUrl(named: "SmokeTestFXL", ofType: ".epub"),
            let zipArchive = ZipArchive(url: epubArchiveUrl) else {
                XCTFail("Couldn't instanciate the .epub obfuscated font archive url")
                return
        }
        obfuscatedFontStreamIdpf = ZipInputStream(zipArchive: zipArchive, path: "fonts/cut-cut.obf.woff")

        // Setup Directory font seekable input stream
        guard let adobeFontUrl = sg.getSamplesUrl(named: "SmokeTestFXL/fonts/cut-cut.adb", ofType: ".woff") else {
            XCTFail("Couldn't generate the adobe font URL.")
            return
        }
        obfuscatedFontStreamAdobe = FileInputStream(fileAtPath: adobeFontUrl.absoluteString)
    }

    func testIdpfFontDeobfuscation() {
        obfuscatedFontStreamIdpf =
            FontDecoder.decodingFont(obfuscatedFontStreamIdpf,
                                                      testPublication.metadata.identifier!,
                                                      FontDecoder.ObfuscationLength.idpf)
        let obfuscatedFontBytes = toData(inputStream: obfuscatedFontStreamIdpf).bytes

        XCTAssertTrue(containSameElements(testFontBytes, obfuscatedFontBytes))
    }

    /// Test deobfuscation time.
    func testIdpfFontDeobfuscationDuration() {
        self.measure {
            let _ = FontDecoder.decodingFont(self.obfuscatedFontStreamIdpf,
                               self.testPublication.metadata.identifier!,
                               FontDecoder.ObfuscationLength.idpf)
        }
    }

    func testAdobeFontDeobfuscation() {
        obfuscatedFontStreamAdobe = FontDecoder.decodingFont(obfuscatedFontStreamAdobe,
                                                  testPublication.metadata.identifier!,
                                                  FontDecoder.ObfuscationLength.adobe)
        let obfuscatedFontBytes = toData(inputStream: obfuscatedFontStreamAdobe).bytes

        XCTAssertTrue(containSameElements(testFontBytes, obfuscatedFontBytes))
    }

    /// Test deobfuscation time.
    func testAdobeFontDeobfuscationDuration() {
        self.measure {
            let _ = FontDecoder.decodingFont(self.obfuscatedFontStreamAdobe,
                               self.testPublication.metadata.identifier!,
                               FontDecoder.ObfuscationLength.adobe)
        }
    }

    /// Check if two arrays contains the same elements.
    ///
    /// - Parameters:
    ///   - array1: The first array to compare.
    ///   - array2: The second array to compare.
    /// - Returns: A boolean indicating if the arrays contains the same elements
    fileprivate func containSameElements<T: Comparable>(_ array1: [T], _ array2: [T]) -> Bool {
        guard array1.count == array2.count else {
            return false // No need to sorting if they already have different counts
        }
        var i = 0

        while i < 1040 {
            i += 1
        }

        return array1.sorted() == array2.sorted()
    }

    /// Convert an InputStream into Data.
    ///
    /// - Parameter input: The `SeekableInputStream` to convert.
    /// - Returns: The converted `Data`.
    fileprivate func toData(inputStream input: SeekableInputStream) -> Data {
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        var data = Data()

        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            data.append(buffer, count: read)
        }
        buffer.deallocate()
        return data
    }
}
