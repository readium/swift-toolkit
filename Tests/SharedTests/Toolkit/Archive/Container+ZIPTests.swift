//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

private let fixtures = Fixtures(path: "Archive")

struct ZIPTester {
    let make: (FileURL) async throws -> Container

    func testOpenSuccess() async throws {
        _ = try await make(fixtures.url(for: "test.zip"))
    }

    func testOpenNotFound() async {
        do {
            _ = try await make(fixtures.url(for: "unknown.zip"))
            XCTFail("Expected an error")
        } catch {}
    }

    func testOpenNotAZIP() async {
        do {
            _ = try await make(fixtures.url(for: "not-a.zip"))
            XCTFail("Expected an error")
        } catch {}
    }

    func testGetNonExistingEntry() async throws {
        let container = try await make(fixtures.url(for: "test.zip"))
        XCTAssertNil(container[AnyURL(path: "unknown")!])
    }

    func testEntries() async throws {
        let container = try await make(fixtures.url(for: "test.zip"))

        XCTAssertEqual(
            container.entries,
            Set([
                AnyURL(path: ".hidden")!,
                AnyURL(path: "A folder/Sub.folder%/file.txt")!,
                AnyURL(path: "A folder/wasteland-cover.jpg")!,
                AnyURL(path: "root.txt")!,
                AnyURL(path: "uncompressed.jpg")!,
                AnyURL(path: "uncompressed.txt")!,
                AnyURL(path: "A folder/Sub.folder%/file-compressed.txt")!,
            ])
        )
    }

    func testResources() async throws {
        let container = try await make(fixtures.url(for: "test.zip"))

        try await AssertEntry(path: ".hidden", in: container, isCompressed: false, length: 0, originalLength: 0)
        try await AssertEntry(path: "A folder/Sub.folder%/file.txt", in: container, isCompressed: false, length: 20, originalLength: 20)
        try await AssertEntry(path: "A folder/wasteland-cover.jpg", in: container, isCompressed: true, length: 82374, originalLength: 103_477)
        try await AssertEntry(path: "root.txt", in: container, isCompressed: false, length: 0, originalLength: 0)
        try await AssertEntry(path: "uncompressed.jpg", in: container, isCompressed: false, length: 279_551, originalLength: 279_551)
        try await AssertEntry(path: "uncompressed.txt", in: container, isCompressed: false, length: 30, originalLength: 30)
        try await AssertEntry(path: "A folder/Sub.folder%/file-compressed.txt", in: container, isCompressed: true, length: 8659, originalLength: 29609)
    }

    func testReadCompressedEntry() async throws {
        let container = try await make(fixtures.url(for: "test.zip"))
        let entry = try XCTUnwrap(container[AnyURL(path: "A folder/Sub.folder%/file-compressed.txt")!])
        let data = try await entry.read().get()
        let string = String(data: data, encoding: .utf8)!
        XCTAssertEqual(string.count, 29609)
        XCTAssertTrue(string.hasPrefix("I'm inside\nthe ZIP."))
    }

    func testReadUncompressedEntry() async throws {
        let container = try await make(fixtures.url(for: "test.zip"))
        let entry = try XCTUnwrap(container[AnyURL(path: "A folder/Sub.folder%/file.txt")!])
        let data = try await entry.read().get()
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            "I'm inside\nthe ZIP.\n"
        )
    }

    func testReadUncompressedRange() async throws {
        // FIXME: It looks like unzseek64 starts from the beginning of the file header, instead of the content. Reading a first byte solves this but then Minizip crashes randomly... Note that this only fails in the test case. I didn't see actual issues in LCPDF or videos embedded in EPUBs.
        let container = try await make(fixtures.url(for: "test.zip"))
        let entry = try XCTUnwrap(container[AnyURL(path: "A folder/Sub.folder%/file.txt")!])
        let data = try await entry.read(range: 14 ..< 20).get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            " ZIP.\n"
        )
    }

    func testReadCompressedRange() async throws {
        let container = try await make(fixtures.url(for: "test.zip"))
        let entry = try XCTUnwrap(container[AnyURL(path: "A folder/Sub.folder%/file-compressed.txt")!])
        let data = try await entry.read(range: 14 ..< 20).get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            " ZIP.\n"
        )
    }

    private func AssertEntry(
        path: String,
        in container: Container,
        isCompressed: Bool,
        length: UInt64,
        originalLength: UInt64
    ) async throws {
        let resource = try XCTUnwrap(container[AnyURL(path: path)!])

        let estimatedLength = try await resource.estimatedLength().get()
        XCTAssertEqual(estimatedLength, originalLength)

        let properties = try await resource.properties().get()
        XCTAssertEqual(
            properties.archive,
            ArchiveProperties(
                entryLength: length,
                isEntryCompressed: isCompressed
            )
        )
    }
}

class MinizipTests: XCTestCase {
    lazy var tester = ZIPTester {
        try await MinizipContainer.make(file: $0).get()
    }

    func testOpenSuccess() async throws { try await tester.testOpenSuccess() }
    func testOpenNotFound() async { await tester.testOpenNotFound() }
    func testOpenNotAZIP() async { await tester.testOpenNotAZIP() }
    func testGetNonExistingEntry() async throws { try await tester.testGetNonExistingEntry() }
    func testEntries() async throws { try await tester.testEntries() }
    func testResources() async throws { try await tester.testResources() }
    func testReadCompressedEntry() async throws { try await tester.testReadCompressedEntry() }
    func testReadUncompressedEntry() async throws { try await tester.testReadUncompressedEntry() }
    func testReadCompressedRange() async throws { try await tester.testReadCompressedRange() }
    func testReadUncompressedRange() async throws { try await tester.testReadUncompressedRange() }
}

// class ZIPFoundationTests: XCTestCase {
//
//    lazy var tester = ZIPTester {
//        url in try ZIPFoundation.make(url: url).get()
//    }
//
// func testOpenSuccess() async throws { try await tester.testOpenSuccess() }
// func testOpenNotFound() async { await tester.testOpenNotFound() }
// func testOpenNotAZIP() async { await tester.testOpenNotAZIP() }
// func testGetNonExistingEntry() async throws { try await tester.testGetNonExistingEntry() }
// func testEntries() async throws { try await tester.testEntries() }
// func testResources() async throws { try await tester.testResources() }
// func testReadCompressedEntry() async throws { try await tester.testReadCompressedEntry() }
// func testReadUncompressedEntry() async throws { try await tester.testReadUncompressedEntry() }
// func testReadCompressedRange() async throws { try await tester.testReadCompressedRange() }
// func testReadUncompressedRange() async throws { try await tester.testReadUncompressedRange() }
//
// }

class ZIPBenchmarkingTests: XCTestCase {
    func testCompareRange() async throws {
        let containers: [Container] = [
            try! await MinizipContainer.make(file: fixtures.url(for: "test.zip")).get(),
//            try! ZIPFoundationArchive(url: fixtures.url(for: "test.zip"))
        ]
        let path = AnyURL(path: "A folder/wasteland-cover.jpg")!
        let length: UInt64 = 103_477

        let entries = try containers
            .map { try XCTUnwrap($0[path]) }

        measure {
            let exp = expectation(description: "Finished")
            Task {
                let lower = UInt64.random(in: 0 ..< length - 100)
                let upper = UInt64.random(in: lower ..< length)
                let range = lower ..< upper
                let datas = await entries.map { await $0.read(range: range).getOrNil() }
                let data = datas[0]
                XCTAssertTrue(datas.allSatisfy { $0 == data })
                exp.fulfill()
            }
            wait(for: [exp], timeout: 200.0)
        }
    }
}
