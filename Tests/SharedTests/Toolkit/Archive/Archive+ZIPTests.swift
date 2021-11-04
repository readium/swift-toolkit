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

struct ZIPTester {
    let make: (URL) throws -> Archive

    func testOpenSuccess() {
        XCTAssertNoThrow(try make(fixtures.url(for: "test.zip")))
    }

    func testOpenNotFound() {
        XCTAssertThrowsError(try make(fixtures.url(for: "unknown.zip")))
    }
    
    func testOpenNotAZIP() {
        XCTAssertThrowsError(try make(fixtures.url(for: "not-a.zip")))
    }
    
    func testGetNonExistingEntry() throws {
        let archive = try make(fixtures.url(for: "test.zip"))
        XCTAssertNil(archive.entry(at: "/unknown"))
    }

    func testGetFileEntry() throws {
        let archive = try make(fixtures.url(for: "test.zip"))
        XCTAssertEqual(
            archive.entry(at: "/A folder/wasteland-cover.jpg"),
            ArchiveEntry(
                path: "/A folder/wasteland-cover.jpg",
                length: 103477,
                compressedLength: 82374
            )
        )
    }

    func testGetUncompressedFileEntry() throws {
        let archive = try make(fixtures.url(for: "test.zip"))
        XCTAssertEqual(
            archive.entry(at: "/uncompressed.jpg"),
            ArchiveEntry(
                path: "/uncompressed.jpg",
                length: 279551,
                compressedLength: nil
            )
        )
    }

    func testGetDirectoryEntry() throws {
        let archive = try make(fixtures.url(for: "test.zip"))
        XCTAssertNil(archive.entry(at: "/A folder"))
        XCTAssertNil(archive.entry(at: "/A folder/"))
    }
    
    func testGetEntries() throws {
        let archive = try make(fixtures.url(for: "test.zip"))
        XCTAssertEqual(archive.entries, [
            ArchiveEntry(path: "/.hidden", length: 0, compressedLength: nil),
            ArchiveEntry(path: "/A folder/Sub.folder%/file.txt", length: 20, compressedLength: nil),
            ArchiveEntry(path: "/A folder/wasteland-cover.jpg", length: 103477, compressedLength: 82374),
            ArchiveEntry(path: "/root.txt", length: 0, compressedLength: nil),
            ArchiveEntry(path: "/uncompressed.jpg", length: 279551, compressedLength: nil),
            ArchiveEntry(path: "/uncompressed.txt", length: 30, compressedLength: nil),
            ArchiveEntry(path: "/A folder/Sub.folder%/file-compressed.txt", length: 29609, compressedLength: 8659),
        ])
    }

    func testReadCompressedEntry() throws {
        let archive = try make(fixtures.url(for: "test.zip"))
        let entry = try XCTUnwrap(archive.readEntry(at: "/A folder/Sub.folder%/file-compressed.txt"))
        let data = try entry.read().get()
        let string = String(data: data, encoding: .utf8)!
        XCTAssertEqual(string.count, 29609)
        XCTAssertTrue(string.hasPrefix("I'm inside\nthe ZIP."))
    }
    
    func testReadUncompressedEntry() throws {
        let archive = try make(fixtures.url(for: "test.zip"))
        let entry = try XCTUnwrap(archive.readEntry(at: "/A folder/Sub.folder%/file.txt"))
        let data = try entry.read().get()
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            "I'm inside\nthe ZIP.\n"
        )
    }
    
    func testReadUncompressedRange() throws {
        // FIXME: It looks like unzseek64 starts from the beginning of the file header, instead of the content. Reading a first byte solves this but then Minizip crashes randomly... Note that this only fails in the test case. I didn't see actual issues in LCPDF or videos embedded in EPUBs.
        let archive = try make(fixtures.url(for: "test.zip"))
        let entry = try XCTUnwrap(archive.readEntry(at: "/A folder/Sub.folder%/file.txt"))
        let data = try entry.read(range: 14..<20).get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            " ZIP.\n"
        )
    }
    
    func testReadCompressedRange() throws {
        let archive = try make(fixtures.url(for: "test.zip"))
        let entry = try XCTUnwrap(archive.readEntry(at: "/A folder/Sub.folder%/file-compressed.txt"))
        let data = try entry.read(range: 14..<20).get()
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            " ZIP.\n"
        )
    }

}

class MinizipTests: XCTestCase {
    
    lazy var tester = ZIPTester {
        url in try MinizipArchive.make(url: url).get()
    }

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

//class ZIPFoundationTests: XCTestCase {
//
//    lazy var tester = ZIPTester {
//        url in try ZIPFoundation.make(url: url).get()
//    }
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

class ZIPBenchmarkingTests: XCTestCase {
    
    func testCompareRange() throws {
        let archives: [Archive] = [
            try! MinizipArchive.make(url: fixtures.url(for: "test.zip")).get(),
//            try! ZIPFoundationArchive(url: fixtures.url(for: "test.zip"))
        ]
        let path = "/A folder/wasteland-cover.jpg"
        let length: UInt64 = 103477

        let entries = try archives
            .map { try XCTUnwrap($0.readEntry(at: path)) }

        measure {
            let lower = UInt64.random(in: 0..<length - 100)
            let upper = UInt64.random(in: lower..<length)
            let range = lower..<upper
            let datas = entries.map { $0.read(range: range).getOrNil() }
            let data = datas[0]
            XCTAssertTrue(datas.allSatisfy { $0 == data })
        }
    }
    
}
