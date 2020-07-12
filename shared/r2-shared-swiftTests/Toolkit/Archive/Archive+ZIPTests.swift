//
//  ArchiveTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 15/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

fileprivate let fixtures = Fixtures(path: "Archive")

struct ZIPTester<A: Archive> {

    func testOpenSuccess() {
        XCTAssertNoThrow(try A(url: fixtures.url(for: "test.zip")))
    }

    func testOpenNotFound() {
        XCTAssertThrowsError(try A(url: fixtures.url(for: "unknown.zip"))) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.openFailed)
        }
    }
    
    func testOpenNotAZIP() {
        XCTAssertThrowsError(try A(url: fixtures.url(for: "not-a.zip"))) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.openFailed)
        }
    }
    
    func testGetNonExistingEntry() throws {
        let archive = try A(url: fixtures.url(for: "test.zip"))
        XCTAssertThrowsError(try archive.entry(at: "unknown")) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.entryNotFound)
        }
    }

    func testGetFileEntry() throws {
        let archive = try A(url: fixtures.url(for: "test.zip"))
        XCTAssertEqual(
            try archive.entry(at: "A folder/wasteland-cover.jpg"),
            ArchiveEntry(
                path: "A folder/wasteland-cover.jpg",
                length: 103477,
                isCompressed: true,
                compressedLength: 82374
            )
        )
    }

    func testGetUncompressedFileEntry() throws {
        let archive = try A(url: fixtures.url(for: "test.zip"))
        XCTAssertEqual(
            try archive.entry(at: "uncompressed.jpg"),
            ArchiveEntry(
                path: "uncompressed.jpg",
                length: 279551,
                isCompressed: false,
                compressedLength: nil
            )
        )
    }

    func testGetDirectoryEntry() throws {
        let archive = try A(url: fixtures.url(for: "test.zip"))
        XCTAssertThrowsError(try archive.entry(at: "A folder")) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.entryNotFound)
        }
        XCTAssertThrowsError(try archive.entry(at: "A folder/")) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.entryNotFound)
        }
    }
    
    func testGetEntries() throws {
        let archive = try A(url: fixtures.url(for: "test.zip"))
        XCTAssertEqual(archive.entries, [
            ArchiveEntry(path: ".hidden", length: 0, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "A folder/Sub.folder%/file.txt", length: 20, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "A folder/wasteland-cover.jpg", length: 103477, isCompressed: true, compressedLength: 82374),
            ArchiveEntry(path: "root.txt", length: 0, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "uncompressed.jpg", length: 279551, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "uncompressed.txt", length: 30, isCompressed: false, compressedLength: nil),
            ArchiveEntry(path: "A folder/Sub.folder%/file-compressed.txt", length: 29609, isCompressed: true, compressedLength: 8659),
        ])
    }

    func testReadCompressedEntry() throws {
        let archive = try A(url: fixtures.url(for: "test.zip"))
        let entry = try archive.entry(at: "A folder/Sub.folder%/file-compressed.txt")
        let data = archive.read(at: entry.path)
        XCTAssertNotNil(data)
        let string = String(data: data!, encoding: .utf8)!
        XCTAssertEqual(string.count, 29609)
        XCTAssertTrue(string.hasPrefix("I'm inside\nthe ZIP."))
    }
    
    func testReadUncompressedEntry() throws {
        let archive = try A(url: fixtures.url(for: "test.zip"))
        let entry = try archive.entry(at: "A folder/Sub.folder%/file.txt")
        let data = archive.read(at: entry.path)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            "I'm inside\nthe ZIP.\n"
        )
    }
    
    func testReadUncompressedRange() throws {
        // FIXME: It looks like unzseek64 starts from the beginning of the file header, instead of the content. Reading a first byte solves this but then Minizip crashes randomly... Note that this only fails in the test case. I didn't see actual issues in LCPDF or videos embedded in EPUBs.
        let archive = try A(url: fixtures.url(for: "test.zip"))
        let entry = try archive.entry(at: "A folder/Sub.folder%/file.txt")
        let data = archive.read(at: entry.path, range: 14..<20)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            " ZIP.\n"
        )
    }
    
    func testReadCompressedRange() throws {
        let archive = try A(url: fixtures.url(for: "test.zip"))
        let entry = try archive.entry(at: "A folder/Sub.folder%/file-compressed.txt")
        let data = archive.read(at: entry.path, range: 14..<20)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            " ZIP.\n"
        )
    }

}

//class ZIPFoundationTests: XCTestCase {
//
//    lazy var tester = ZIPTester<ZIPFoundationArchive>()
//
//    func testOpenSuccess() { tester.testOpenSuccess() }
//    func testOpenNotFound() { tester.testOpenNotFound() }
//    func testOpenNotAZIP() { tester.testOpenNotAZIP() }
//    func testGetNonExistingEntry() throws { try tester.testGetNonExistingEntry() }
//    func testGetFileEntry() throws { try tester.testGetFileEntry() }
//    func testGetUncompressedFileEntry() throws { try tester.testGetUncompressedFileEntry() }
//    func testGetDirectoryEntry() throws { try tester.testGetDirectoryEntry() }
//    func testGetEntries() throws { try tester.testGetEntries() }
//    func testReadCompressedEntry() throws { try tester.testReadCompressedEntry() }
//    func testReadUncompressedEntry() throws { try tester.testReadUncompressedEntry() }
//    func testReadCompressedRange() throws { try tester.testReadCompressedRange() }
//    func testReadUncompressedRange() throws { try tester.testReadUncompressedRange() }
//
//}

class MinizipTests: XCTestCase {
    
    lazy var tester = ZIPTester<MinizipArchive>()
    
    func testOpenSuccess() { tester.testOpenSuccess() }
    func testOpenNotFound() { tester.testOpenNotFound() }
    func testOpenNotAZIP() { tester.testOpenNotAZIP() }
    func testGetNonExistingEntry() throws { try tester.testGetNonExistingEntry() }
    func testGetFileEntry() throws { try tester.testGetFileEntry() }
    func testGetUncompressedFileEntry() throws { try tester.testGetUncompressedFileEntry() }
    func testGetDirectoryEntry() throws { try tester.testGetDirectoryEntry() }
    func testGetEntries() throws { try tester.testGetEntries() }
    func testReadCompressedEntry() throws { try tester.testReadCompressedEntry() }
    func testReadUncompressedEntry() throws { try tester.testReadUncompressedEntry() }
    func testReadCompressedRange() throws { try tester.testReadCompressedRange() }
    func testReadUncompressedRange() throws { try tester.testReadUncompressedRange() }
    
}

class ZIPBenchmarkingTests: XCTestCase {
    
    func testCompareRange() {
        let archives: [Archive] = [
            try! MinizipArchive(url: fixtures.url(for: "test.zip")),
//            try! ZIPFoundationArchive(url: fixtures.url(for: "test.zip"))
        ]
        let path = "A folder/wasteland-cover.jpg"
        let length: UInt64 = 103477

        measure {
            let lower = UInt64.random(in: 0..<length - 100)
            let upper = UInt64.random(in: lower..<length)
            let range = lower..<upper
            let datas = archives.map { $0.read(at: path, range: range) }
            let data = datas[0]
            XCTAssertTrue(datas.allSatisfy { $0 == data })
        }
    }
    
}
