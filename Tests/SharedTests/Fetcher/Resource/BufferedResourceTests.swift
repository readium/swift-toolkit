//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
@testable import R2Shared

class BufferedResourceTests: XCTestCase {

    func testBufferSize() {
        XCTAssertEqual(sut(bufferSize: 1024).bufferSize, 1024)
        XCTAssertEqual(sut(bufferSize: 2048).bufferSize, 2048)
    }

    func testFile() {
        XCTAssertEqual(sut().file, url)
    }

    func testLink() {
        XCTAssertEqual(sut().link, link)
    }

    func testLength() {
        XCTAssertEqual(sut().length, .success(161291))
    }

    func testReadFully() throws {
        try testRead(sut())
    }

    func testReadFullyByChunksSmallerThanBuffer() throws {
        let sut = self.sut(bufferSize: 1024)
        for start in 0..<653 {
            try testRead(sut, range: UInt64(start * 247)..<UInt64((start + 1) * 247))
        }
    }

    func testReadFullyByChunksEqualToBuffer() throws {
        let sut = self.sut(bufferSize: 247)
        for start in 0..<653 {
            try testRead(sut, range: UInt64(start * 247)..<UInt64((start + 1) * 247))
        }
    }

    func testReadFullyByChunksLargerThanBuffer() throws {
        let sut = self.sut(bufferSize: 100)
        for start in 0..<653 {
            try testRead(sut, range: UInt64(start * 247)..<UInt64((start + 1) * 247))
        }
    }

    func testReadUnbufferedRanges() throws {
        try testRead(sut(), range: 0..<850)
        try testRead(sut(), range: 1000..<2048)
        try testRead(sut(), range: 160291..<161291)
    }

    func testReadUnbufferedRangesConsecutively() throws {
        let sut = self.sut(bufferSize: 1024)
        try testRead(sut, range: 0..<850)
        try testRead(sut, range: 1000..<2048)
        try testRead(sut, range: 160291..<161291)
    }

    func testReadBufferedRange() throws {
        let sut = self.sut(bufferSize: 1024)
        try testRead(sut, range: 0..<850)
        try testRead(sut, range: 400..<850)
        try testRead(sut, range: 500..<1000)
        try testRead(sut, range: 1000..<2048)
        try testRead(sut, range: 2048..<4096)
        try testRead(sut, range: 2048..<3072)
        try testRead(sut, range: 1024..<1079)
        try testRead(sut, range: 160291..<161291)
        try testRead(sut, range: 160300..<161270)
    }

    func testReadRangeOverlappingBuffer() throws {
        let sut = self.sut(bufferSize: 1024)

        // Overlapping start
        try testRead(sut, range: 512..<1000)
        try testRead(sut, range: 0..<750)
        try testRead(sut, range: 1024..<2048)
        try testRead(sut, range: 512..<1500)

        // Overlapping end
        try testRead(sut, range: 512..<1000)
        try testRead(sut, range: 750..<4096)
        try testRead(sut, range: 1024..<2048)
        try testRead(sut, range: 1500..<4096)
    }

    func testReadBiggerThanBuffer() throws {
        let sut = self.sut(bufferSize: 1024)
        try testRead(sut, range: 512..<1024)
        try testRead(sut, range: 200..<4096)
    }

    func testReadRandomRanges() throws {
        let sut = self.sut(bufferSize: 8489)
        for _ in 0...10000 {
            let lowerBound = UInt64.random(in: 0..<161291)
            let upperBound = UInt64.random(in: lowerBound..<161291)
            try testRead(sut, range: lowerBound..<upperBound)
        }
    }

    private let link = Link(href: "file")
    private let url = Fixtures(path: "Fetcher").url(for: "epub.epub")
    private lazy var data = try! Data(contentsOf: url)
    private lazy var resource = FileFetcher.FileResource(link: link, file: url)

    private func sut(bufferSize: UInt64 = 1024) -> BufferedResource {
        return BufferedResource(resource: resource, bufferSize: bufferSize)
    }

    func testRead(_ sut: BufferedResource, range: Range<UInt64>? = nil) throws {
        let res = sut.read(range: range)
        XCTAssertEqual(res, resource.read(range: range))
        let readData = try XCTUnwrap(res.getOrNil())
        if let range = range {
            XCTAssertEqual(readData, data[range])
        } else {
            XCTAssertEqual(readData, data)
        }
    }

}

