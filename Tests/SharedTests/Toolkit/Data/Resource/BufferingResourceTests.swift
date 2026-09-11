//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import TestPublications
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

    /// The read-ahead must not request bytes past the end of the resource,
    /// as some resources reject out-of-range requests instead of clamping
    /// them (e.g. HTTP servers reply with a 416 error).
    func testReadNearEndDoesNotOverRequest() async throws {
        let data = Data((0 ..< 2000).map { UInt8($0 % 256) })
        let sut = BufferingResource(resource: StrictResource(data: data), bufferSize: 1024)

        var result = try await sut.read(range: 1900 ..< 2000).get()
        XCTAssertEqual(result, data[1900 ..< 2000])

        result = try await sut.read(range: 1990 ..< 1995).get()
        XCTAssertEqual(result, data[1990 ..< 1995])
    }

    private let file = FileURL(url: TestPublications.url(for: "childrens-literature.epub"))!
    private lazy var data = try! Data(contentsOf: file.url)
    private lazy var resource = FileResource(file: file)

    private func sut(bufferSize: Int = 1024) -> BufferingResource {
        BufferingResource(resource: resource, bufferSize: bufferSize)
    }

    func testRead(_ sut: BufferingResource, range: Range<UInt64>? = nil, file: StaticString = #filePath, line: UInt = #line) async throws {
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

/// A `Resource` that fails when requesting a range past its end, instead of
/// clamping it.
private actor StrictResource: Resource {
    private let data: Data

    init(data: Data) {
        self.data = data
    }

    let sourceURL: AbsoluteURL? = nil

    func estimatedLength() async -> ReadResult<UInt64?> {
        .success(UInt64(data.count))
    }

    func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties())
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        guard let range = range else {
            consume(data)
            return .success(())
        }
        guard range.upperBound <= UInt64(data.count) else {
            return .failure(.decoding("Requested a range out of bounds"))
        }
        consume(data[Int(range.lowerBound) ..< Int(range.upperBound)])
        return .success(())
    }
}
