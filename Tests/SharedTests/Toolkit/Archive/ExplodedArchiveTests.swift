//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

private let fixtures = Fixtures(path: "Archive")

class ExplodedArchiveTests: XCTestCase {
    func testOpenSuccess() {
        XCTAssertNotNil(ExplodedArchive.make(url: fixtures.url(for: "exploded")).getOrNil())
    }

    func testOpenNotFound() {
        XCTAssertThrowsError(try ExplodedArchive.make(url: fixtures.url(for: "unknown-folder")).get())
    }

    func testOpenNotADirectory() {
        XCTAssertThrowsError(try ExplodedArchive.make(url: fixtures.url(for: "test.zip")).get())
    }

    func testGetNonExistingEntry() throws {
        let archive = try ExplodedArchive.make(url: fixtures.url(for: "exploded")).get()
        XCTAssertNil(archive.entry(at: "/unknown"))
    }

    func testGetFileEntry() throws {
        let archive = try ExplodedArchive.make(url: fixtures.url(for: "exploded")).get()
        XCTAssertEqual(
            archive.entry(at: "/A folder/wasteland-cover.jpg"),
            ArchiveEntry(
                path: "/A folder/wasteland-cover.jpg",
                length: 103_477,
                compressedLength: nil
            )
        )
    }

    func testGetDirectoryEntryReturnsNil() throws {
        let archive = try ExplodedArchive.make(url: fixtures.url(for: "exploded")).get()
        XCTAssertNil(archive.entry(at: "/A folder"))
        XCTAssertNil(archive.entry(at: "/A folder/"))
    }

    func testGetEntries() throws {
        let archive = try ExplodedArchive.make(url: fixtures.url(for: "exploded")).get()
        // The entries are sorted by path.
        XCTAssertEqual(archive.entries, [
            ArchiveEntry(path: "/.hidden", length: 0, compressedLength: nil),
            ArchiveEntry(path: "/A folder/Sub.folder%/file-compressed.txt", length: 29609, compressedLength: nil),
            ArchiveEntry(path: "/A folder/Sub.folder%/file.txt", length: 20, compressedLength: nil),
            ArchiveEntry(path: "/A folder/wasteland-cover.jpg", length: 103_477, compressedLength: nil),
            ArchiveEntry(path: "/root.txt", length: 0, compressedLength: nil),
            ArchiveEntry(path: "/uncompressed.jpg", length: 279_551, compressedLength: nil),
            ArchiveEntry(path: "/uncompressed.txt", length: 30, compressedLength: nil),
        ])
    }

    func testCantGetEntryOutsideRoot() throws {
        let archive = try ExplodedArchive.make(url: fixtures.url(for: "exploded")).get()
        XCTAssertNil(archive.entry(at: "../test.zip"))
    }

    func testReadFullEntry() throws {
        let archive = try ExplodedArchive.make(url: fixtures.url(for: "exploded")).get()
        let entry = try XCTUnwrap(archive.readEntry(at: "/A folder/Sub.folder%/file.txt"))
        let data = try entry.read().get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            "I'm inside\nthe ZIP.\n"
        )
    }

    func testReadRange() throws {
        let archive = try ExplodedArchive.make(url: fixtures.url(for: "exploded")).get()
        let entry = try XCTUnwrap(archive.readEntry(at: "/A folder/Sub.folder%/file.txt"))
        let data = try entry.read(range: 14 ..< 20).get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            " ZIP.\n"
        )
    }
}
