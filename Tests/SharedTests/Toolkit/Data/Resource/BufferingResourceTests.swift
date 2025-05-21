//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class BufferingResourceTests: XCTestCase {
    func testSourceURL() {
        XCTAssertEqual(sut().sourceURL?.fileURL, file)
    }

    func testEstimatedLength() async {
        let result = await sut().estimatedLength()
        XCTAssertEqual(result, .success(161_291))
    }

    func testReadFully() async throws {
        try await testRead(sut())
    }

    func testReadFullyByChunksSmallerThanBuffer() async throws {
        let sut = sut(bufferSize: 1024)
        for start in 0 ..< 653 {
            try await testRead(sut, range: UInt64(start * 247) ..< UInt64((start + 1) * 247))
        }
    }

    func testReadFullyByChunksEqualToBuffer() async throws {
        let sut = sut(bufferSize: 247)
        for start in 0 ..< 653 {
            try await testRead(sut, range: UInt64(start * 247) ..< UInt64((start + 1) * 247))
        }
    }

    func testReadFullyByChunksLargerThanBuffer() async throws {
        let sut = sut(bufferSize: 100)
        for start in 0 ..< 653 {
            try await testRead(sut, range: UInt64(start * 247) ..< UInt64((start + 1) * 247))
        }
    }

    func testReadUnbufferedRanges() async throws {
        try await testRead(sut(), range: 0 ..< 850)
        try await testRead(sut(), range: 1000 ..< 2048)
        try await testRead(sut(), range: 160_291 ..< 161_291)
    }

    func testReadUnbufferedRangesConsecutively() async throws {
        let sut = sut(bufferSize: 1024)
        try await testRead(sut, range: 0 ..< 850)
        try await testRead(sut, range: 1000 ..< 2048)
        try await testRead(sut, range: 160_291 ..< 161_291)
    }

    func testReadBufferedRange() async throws {
        let sut = sut(bufferSize: 1024)
        try await testRead(sut, range: 0 ..< 850)
        try await testRead(sut, range: 400 ..< 850)
        try await testRead(sut, range: 500 ..< 1000)
        try await testRead(sut, range: 1000 ..< 2048)
        try await testRead(sut, range: 2048 ..< 4096)
        try await testRead(sut, range: 2048 ..< 3072)
        try await testRead(sut, range: 1024 ..< 1079)
        try await testRead(sut, range: 160_291 ..< 161_291)
        try await testRead(sut, range: 160_300 ..< 161_270)
    }

    func testReadRangeOverlappingBuffer() async throws {
        let sut = sut(bufferSize: 1024)

        // Overlapping start
        try await testRead(sut, range: 512 ..< 1000)
        try await testRead(sut, range: 0 ..< 750)
        try await testRead(sut, range: 1024 ..< 2048)
        try await testRead(sut, range: 512 ..< 1500)

        // Overlapping end
        try await testRead(sut, range: 512 ..< 1000)
        try await testRead(sut, range: 750 ..< 4096)
        try await testRead(sut, range: 1024 ..< 2048)
        try await testRead(sut, range: 1500 ..< 4096)
    }

    func testReadBiggerThanBuffer() async throws {
        let sut = sut(bufferSize: 1024)
        try await testRead(sut, range: 512 ..< 1024)
        try await testRead(sut, range: 200 ..< 4096)
    }

    func testReadRandomRanges() async throws {
        let sut = sut(bufferSize: 8489)
        for _ in 0 ... 10000 {
            let lowerBound = UInt64.random(in: 0 ..< 161_291)
            let upperBound = UInt64.random(in: lowerBound ..< 161_291)
            try await testRead(sut, range: lowerBound ..< upperBound)
        }
    }

    private let file = Fixtures(path: "Fetcher").url(for: "epub.epub")
    private lazy var data = try! Data(contentsOf: file.url)
    private lazy var resource = FileResource(file: file)

    private func sut(bufferSize: Int = 1024) -> BufferingResource {
        BufferingResource(resource: resource, bufferSize: bufferSize)
    }

    func testRead(_ sut: BufferingResource, range: Range<UInt64>? = nil, file: StaticString = #file, line: UInt = #line) async throws {
        let res = await sut.read(range: range)
        let expected = await resource.read(range: range)
        XCTAssertEqual(res, expected, file: file, line: line)
        let readData = try XCTUnwrap(res.getOrNil())
        if let range = range {
            XCTAssertEqual(readData, data[range], file: file, line: line)
        } else {
            XCTAssertEqual(readData, data, file: file, line: line)
        }
    }
}
