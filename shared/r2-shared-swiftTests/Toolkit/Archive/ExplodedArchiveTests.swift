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
        XCTAssertNoThrow(try ExplodedArchive(url: fixtures.url(for: "exploded")))
    }
    
    func testOpenNotFound() {
        XCTAssertThrowsError(try ExplodedArchive(url: fixtures.url(for: "unknown-folder"))) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.openFailed)
        }
    }
    
    func testOpenNotADirectory() {
        XCTAssertThrowsError(try ExplodedArchive(url: fixtures.url(for: "test.zip"))) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.openFailed)
        }
    }
   
    func testGetNonExistingEntry() throws {
        let archive = try ExplodedArchive(url: fixtures.url(for: "exploded"))
        XCTAssertThrowsError(try archive.entry(at: "unknown")) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.entryNotFound)
        }
    }
    
    func testGetFileEntry() throws {
        let archive = try ExplodedArchive(url: fixtures.url(for: "exploded"))
        XCTAssertEqual(
            try archive.entry(at: "A folder/wasteland-cover.jpg"),
            ArchiveEntry(
                path: "A folder/wasteland-cover.jpg",
                length: 103477,
                isCompressed: false,
                compressedLength: nil
            )
        )
    }

    func testGetDirectoryEntry() throws {
        let archive = try ExplodedArchive(url: fixtures.url(for: "exploded"))
        XCTAssertThrowsError(try archive.entry(at: "A folder")) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.entryNotFound)
        }
        XCTAssertThrowsError(try archive.entry(at: "A folder/")) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.entryNotFound)
        }
    }
    
    func testGetEntries() throws {
        let archive = try ExplodedArchive(url: fixtures.url(for: "exploded"))
        // The entries are sorted by path.
        XCTAssertEqual(archive.entries, [
            ArchiveEntry(path: ".hidden", length: 0, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "A folder/Sub.folder%/file-compressed.txt", length: 29609, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "A folder/Sub.folder%/file.txt", length: 20, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "A folder/wasteland-cover.jpg", length: 103477, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "root.txt", length: 0, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "uncompressed.jpg", length: 279551, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "uncompressed.txt", length: 30, isCompressed: false, compressedLength: nil),
        ])
    }
    
    func testCantGetEntryOutsideRoot() throws {
        let archive = try ExplodedArchive(url: fixtures.url(for: "exploded"))
        XCTAssertThrowsError(try archive.entry(at: "../test.zip")) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.entryNotFound)
        }
    }

    func testReadFullEntry() throws {
        let archive = try ExplodedArchive(url: fixtures.url(for: "exploded"))
        let entry = try archive.entry(at: "A folder/Sub.folder%/file.txt")
        let data = archive.read(at: entry.path)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            "I'm inside\nthe ZIP.\n"
        )
    }
    
    func testReadRange() throws {
        let archive = try ExplodedArchive(url: fixtures.url(for: "exploded"))
        let entry = try archive.entry(at: "A folder/Sub.folder%/file.txt")
        let data = archive.read(at: entry.path, range: 14..<20)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            " ZIP.\n"
        )
    }

}
