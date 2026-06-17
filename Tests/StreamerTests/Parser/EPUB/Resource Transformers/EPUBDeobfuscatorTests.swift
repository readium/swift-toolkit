//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class EPUBDeobfuscatorTests: XCTestCase {
    let fixtures = Fixtures(path: "EPUBDeobfuscator")

    var font: Data!

    override func setUpWithError() throws {
        font = fixtures.data(at: "cut-cut.woff")
    }

    func testDeobfuscateIDPF() async throws {
        let sut = try sut(resourcePath: "cut-cut.obf.woff", algorithm: "http://www.idpf.org/2008/embedding")
        let result = await sut.deobfuscate(nil)
        XCTAssertEqual(result, .success(font))
    }

    func testDeobfuscateAdobe() async throws {
        let sut = try sut(resourcePath: "cut-cut.adb.woff", algorithm: "http://ns.adobe.com/pdf/enc#RC")
        let result = await sut.deobfuscate(nil)
        XCTAssertEqual(result, .success(font))
    }

    /// Reading a sub-range starting inside the obfuscated region must produce
    /// the same bytes as the matching range of the clear-text resource.
    ///
    /// Regression test: the key index must be derived from the absolute
    /// position in the resource, not from the offset within the streamed
    /// chunk. We start at a position that is not aligned on the key length so
    /// a chunk-local index would yield a different (wrong) key byte.
    func testDeobfuscateRangeWithinObfuscatedRegion() async throws {
        let range: Range<UInt64> = 105 ..< 400

        for (path, algorithm) in [
            ("cut-cut.obf.woff", "http://www.idpf.org/2008/embedding"),
            ("cut-cut.adb.woff", "http://ns.adobe.com/pdf/enc#RC"),
        ] {
            let sut = try sut(resourcePath: path, algorithm: algorithm)
            let result = await sut.deobfuscate(range)
            let expected = Data(font[Int(range.lowerBound) ..< Int(range.upperBound)])
            XCTAssertEqual(result, .success(expected), "algorithm: \(algorithm)")
        }
    }

    /// Reading a range that spans the boundary of the obfuscated region must
    /// deobfuscate only the bytes within the region and leave the rest intact.
    func testDeobfuscateRangeAcrossObfuscatedBoundary() async throws {
        // IDPF obfuscates the first 1040 bytes.
        let range: Range<UInt64> = 1000 ..< 1100

        let sut = try sut(resourcePath: "cut-cut.obf.woff", algorithm: "http://www.idpf.org/2008/embedding")
        let result = await sut.deobfuscate(range)
        let expected = Data(font[Int(range.lowerBound) ..< Int(range.upperBound)])
        XCTAssertEqual(result, .success(expected))
    }

    /// Fix for https://github.com/readium/r2-streamer-swift/issues/208
    func testEmptyPublicationID() async throws {
        let file = fixtures.data(at: "nav.xhtml")

        var sut = try sut(publicationID: "urn:uuid:", resourcePath: "nav.xhtml", algorithm: "http://www.idpf.org/2008/embedding")
        var result = await sut.deobfuscate(nil)
        XCTAssertEqual(result, .success(file))

        sut = try self.sut(publicationID: "", resourcePath: "nav.xhtml", algorithm: "http://www.idpf.org/2008/embedding")
        result = await sut.deobfuscate(nil)
        XCTAssertEqual(result, .success(file))
    }

    private func sut(
        publicationID: String = "urn:uuid:36d5078e-ff7d-468e-a5f3-f47c14b91f2f",
        resourcePath path: String,
        algorithm: String
    ) throws -> (
        deobfuscate: (Range<UInt64>?) async -> ReadResult<Data>,
        resource: DataResource,
        encryptions: [RelativeURL: Encryption]
    ) {
        let url = try XCTUnwrap(RelativeURL(path: path))
        let data = fixtures.data(at: path)
        let resource = DataResource(data: data)
        let encryptions = [url: Encryption(algorithm: algorithm)]
        let deobfuscator = EPUBDeobfuscator(
            publicationId: publicationID,
            encryptions: encryptions
        )
        return (
            deobfuscate: { range in
                await deobfuscator.deobfuscate(resource: resource, at: url.anyURL).read(range: range)
            },
            resource: resource,
            encryptions: [url: Encryption(algorithm: algorithm)]
        )
    }
}
