//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import TestPublications
import XCTest

class TailCachingResourceTests: XCTestCase {
    func testSourceURL() {
        XCTAssertEqual(sut(cacheFrom: 0).sourceURL?.fileURL, file)
    }

    func testEstimatedLength() async throws {
        let result = try await sut(cacheFrom: 0).estimatedLength()
        XCTAssertEqual(result, 161_291)
    }

    func testReadNothingCached() async throws {
        try await testRead(sut(cacheFrom: .max))
    }

    func testReadFullyCached() async throws {
        try await testRead(sut(cacheFrom: 0))
    }

    func testCacheFromLargerThanResource() async throws {
        try await testRead(sut(cacheFrom: 180_000))
    }

    func testReadChunks() async throws {
        let sut = sut(cacheFrom: 160_000)

        try await testRead(sut, range: 150_000 ..< 159_999)
        // Overlapping cache.
        try await testRead(sut, range: 158_000 ..< 161_000)
        try await testRead(sut, range: 160_000 ..< 161_000)
        try await testRead(sut, range: 160_001 ..< 161_000)
        try await testRead(sut, range: 160_001 ..< 161_291)
        try await testRead(sut, range: 160_001 ..< .max)
    }

    func testReadRandomRanges() async throws {
        let sut = sut(cacheFrom: 161_291 / 2)
        for _ in 0 ... 10000 {
            let lowerBound = UInt64.random(in: 0 ..< 161_291)
            let upperBound = UInt64.random(in: lowerBound ..< 161_291)
            try await testRead(sut, range: lowerBound ..< upperBound)
        }
    }

    private let file = FileURL(url: TestPublications.url(for: "childrens-literature.epub"))!
    private lazy var data = try! Data(contentsOf: file.url)
    private lazy var resource = FileResource(file: file)

    private func sut(cacheFrom: UInt64) -> TailCachingResource {
        TailCachingResource(resource: resource, cacheFromOffset: cacheFrom)
    }

    func testRead(_ sut: TailCachingResource, range: Range<UInt64>? = nil, file: StaticString = #file, line: UInt = #line) async throws {
        let readData = try await sut.read(range: range)
        let expected = try await resource.read(range: range)
        XCTAssertEqual(readData, expected, file: file, line: line)
        if var range = range {
            range = range.clamped(to: 0 ..< UInt64(data.count))
            XCTAssertEqual(readData, data[range], file: file, line: line)
        } else {
            XCTAssertEqual(readData, data, file: file, line: line)
        }
    }
}
