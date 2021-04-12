//
//  ExplodedArchiveTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

fileprivate let fixtures = Fixtures(path: "Archive")

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
                length: 103477,
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
            ArchiveEntry(path: "/A folder/wasteland-cover.jpg", length: 103477, compressedLength: nil),
            ArchiveEntry(path: "/root.txt", length: 0, compressedLength: nil),
            ArchiveEntry(path: "/uncompressed.jpg", length: 279551, compressedLength: nil),
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
        let data = try entry.read(range: 14..<20).get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            " ZIP.\n"
        )
    }

}
