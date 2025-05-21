//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

private let fixtures = Fixtures(path: "Archive")

class DirectoryContainerTests: XCTestCase {
    func testOpenNotFound() async {
        do {
            _ = try await DirectoryContainer(directory: fixtures.url(for: "unknown-folder"))
        } catch is DirectoryContainer.NotADirectoryError {
            return
        } catch {}
        XCTFail("Expected an error")
    }

    func testOpenNotADirectory() async {
        do {
            _ = try await DirectoryContainer(directory: fixtures.url(for: "test.zip"))
            XCTFail("Expected an error")
        } catch is DirectoryContainer.NotADirectoryError {
            return
        } catch {}
        XCTFail("Expected an error")
    }

    func testGetNonExistingEntry() async throws {
        let container = try await DirectoryContainer(directory: fixtures.url(for: "exploded"))
        XCTAssertNil(container[AnyURL(path: "unknown")!])
    }

    func testEntries() async throws {
        let container = try await DirectoryContainer(directory: fixtures.url(for: "exploded"))

        XCTAssertEqual(container.entries, Set([
            AnyURL(path: "A folder/Sub.folder%/file-compressed.txt")!,
            AnyURL(path: "A folder/Sub.folder%/file.txt")!,
            AnyURL(path: "A folder/wasteland-cover.jpg")!,
            AnyURL(path: "root.txt")!,
            AnyURL(path: "uncompressed.jpg")!,
            AnyURL(path: "uncompressed.txt")!,
        ]))
    }

    func testHiddenEntries() async throws {
        let container = try await DirectoryContainer(directory: fixtures.url(for: "exploded"), options: [])
        XCTAssertTrue(container.entries.contains(AnyURL(path: ".hidden")!))
    }

    func testResources() async throws {
        let container = try await DirectoryContainer(directory: fixtures.url(for: "exploded"))

        try await AssertEntry(path: "A folder/Sub.folder%/file-compressed.txt", in: container, length: 29609)
        try await AssertEntry(path: "A folder/Sub.folder%/file.txt", in: container, length: 20)
        try await AssertEntry(path: "A folder/wasteland-cover.jpg", in: container, length: 103_477)
        try await AssertEntry(path: "root.txt", in: container, length: 0)
        try await AssertEntry(path: "uncompressed.jpg", in: container, length: 279_551)
        try await AssertEntry(path: "uncompressed.txt", in: container, length: 30)
    }

    func testCantGetEntryOutsideRoot() async throws {
        let container = try await DirectoryContainer(directory: fixtures.url(for: "exploded"))
        XCTAssertNil(container[AnyURL(path: "../test.zip")!])
    }

    func testReadFullEntry() async throws {
        let container = try await DirectoryContainer(directory: fixtures.url(for: "exploded"))
        let entry = try XCTUnwrap(container[AnyURL(path: "A folder/Sub.folder%/file.txt")!])
        let data = try await entry.read().get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            "I'm inside\nthe ZIP.\n"
        )
    }

    func testReadRange() async throws {
        let container = try await DirectoryContainer(directory: fixtures.url(for: "exploded"))
        let entry = try XCTUnwrap(container[AnyURL(path: "A folder/Sub.folder%/file.txt")!])
        let data = try await entry.read(range: 14 ..< 20).get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            " ZIP.\n"
        )
    }

    private func AssertEntry(
        path: String,
        in container: Container,
        length: UInt64
    ) async throws {
        let resource = try XCTUnwrap(container[AnyURL(path: path)!])
        let estimatedLength = try await resource.estimatedLength().get()
        XCTAssertEqual(estimatedLength, length)
    }
}
