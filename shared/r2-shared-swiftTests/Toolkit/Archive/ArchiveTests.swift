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

fileprivate let fixtures = Fixtures(path: "ZIP")

struct ZIPTester<A: Archive> {

    func testOpenSuccess() {
        XCTAssertNoThrow(try A(file: fixtures.url(for: "test.zip")))
    }

    func testOpenNotFound() {
        XCTAssertThrowsError(try A(file: fixtures.url(for: "unknown.zip"))) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.openFailed)
        }
    }
    
    func testOpenNotAZIP() {
        XCTAssertThrowsError(try A(file: fixtures.url(for: "not-a.zip"))) { error in
            XCTAssertEqual(error as? ArchiveError, ArchiveError.openFailed)
        }
    }
    
    func testGetNonExistingEntry() {
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "unknown")
        XCTAssertNil(entry)
    }

    func testGetFileEntry() {
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        XCTAssertEqual(
            archive.entry(at: "A folder/wasteland-cover.jpg"),
            ArchiveEntry(
                path: "A folder/wasteland-cover.jpg",
                isDirectory: false,
                length: 103477,
                isCompressed: true,
                compressedLength: 82374
            )
        )
    }

    func testGetUncompressedFileEntry() {
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        XCTAssertEqual(
            archive.entry(at: "uncompressed.jpg"),
            ArchiveEntry(
                path: "uncompressed.jpg",
                isDirectory: false,
                length: 279551,
                isCompressed: false,
                compressedLength: 279551
            )
        )
    }

    func testGetDirectoryEntry() {
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        XCTAssertNil(archive.entry(at: "A folder"))
        XCTAssertEqual(
            archive.entry(at: "A folder/"),
            ArchiveEntry(
                path: "A folder/",
                isDirectory: true,
                length: 0,
                isCompressed: false,
                compressedLength: 0
            )
        )
    }
    
    func testGetEntries() {
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        XCTAssertEqual(archive.entries, [
            ArchiveEntry(path: ".hidden", isDirectory: false, length: 0, isCompressed: false, compressedLength: 0),
            ArchiveEntry(path: "A folder/", isDirectory: true, length: 0, isCompressed: false, compressedLength: 0),
            ArchiveEntry(path: "A folder/Sub.folder%/", isDirectory: true, length: 0, isCompressed: false, compressedLength: 0),
            ArchiveEntry(path: "A folder/Sub.folder%/file.txt", isDirectory: false, length: 20, isCompressed: false, compressedLength: 20),
            ArchiveEntry(path: "A folder/wasteland-cover.jpg", isDirectory: false, length: 103477, isCompressed: true, compressedLength: 82374),
            ArchiveEntry(path: "root.txt", isDirectory: false, length: 0, isCompressed: false, compressedLength: 0),
            ArchiveEntry(path: "uncompressed.jpg", isDirectory: false, length: 279551, isCompressed: false, compressedLength: 279551),
            ArchiveEntry(path: "uncompressed.txt", isDirectory: false, length: 30, isCompressed: false, compressedLength: 30),
            ArchiveEntry(path: "A folder/Sub.folder%/file-compressed.txt", isDirectory: false, length: 29609, isCompressed: true, compressedLength: 8659),
        ])
    }

    func testReadCompressedEntry() {
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "A folder/Sub.folder%/file-compressed.txt")!
        let data = archive.read(at: entry.path)
        XCTAssertNotNil(data)
        let string = String(data: data!, encoding: .utf8)!
        XCTAssertEqual(string.count, 29609)
        XCTAssertTrue(string.hasPrefix("I'm inside\nthe ZIP."))
    }
    
    func testReadUncompressedEntry() {
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "A folder/Sub.folder%/file.txt")!
        let data = archive.read(at: entry.path)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            "I'm inside\nthe ZIP.\n"
        )
    }
    
    func testReadUncompressedRange() {
        // FIXME: It looks like unzseek64 starts from the beginning of the file header, instead of the content. Reading a first byte solves this but then Minizip crashes randomly... Note that this only fails in the test case. I didn't see actual issues in LCPDF or videos embedded in EPUBs.
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "A folder/Sub.folder%/file.txt")!
        let data = archive.read(at: entry.path, range: 14..<20)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            " ZIP.\n"
        )
    }
    
    func testReadCompressedRange() {
        let archive = try! A(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "A folder/Sub.folder%/file-compressed.txt")!
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
//    func testGetNonExistingEntry() { tester.testGetNonExistingEntry() }
//    func testGetFileEntry() { tester.testGetFileEntry() }
//    func testGetUncompressedFileEntry() { tester.testGetUncompressedFileEntry() }
//    func testGetDirectoryEntry() { tester.testGetDirectoryEntry() }
//    func testGetEntries() { tester.testGetEntries() }
//    func testReadCompressedEntry() { tester.testReadCompressedEntry() }
//    func testReadUncompressedEntry() { tester.testReadUncompressedEntry() }
//    func testReadCompressedRange() { tester.testReadCompressedRange() }
//    func testReadUncompressedRange() { tester.testReadUncompressedRange() }
//
//}

class MinizipTests: XCTestCase {
    
    lazy var tester = ZIPTester<MinizipArchive>()
    
    func testOpenSuccess() { tester.testOpenSuccess() }
    func testOpenNotFound() { tester.testOpenNotFound() }
    func testOpenNotAZIP() { tester.testOpenNotAZIP() }
    func testGetNonExistingEntry() { tester.testGetNonExistingEntry() }
    func testGetFileEntry() { tester.testGetFileEntry() }
    func testGetUncompressedFileEntry() { tester.testGetUncompressedFileEntry() }
    func testGetDirectoryEntry() { tester.testGetDirectoryEntry() }
    func testGetEntries() { tester.testGetEntries() }
    func testReadCompressedEntry() { tester.testReadCompressedEntry() }
    func testReadUncompressedEntry() { tester.testReadUncompressedEntry() }
    func testReadCompressedRange() { tester.testReadCompressedRange() }
    func testReadUncompressedRange() { tester.testReadUncompressedRange() }
    
}

class ZIPBenchmarkingTests: XCTestCase {
    
    func testCompareRange() {
        let archives: [Archive] = [
            try! MinizipArchive(file: fixtures.url(for: "test.zip")),
//            try! ZIPFoundationArchive(file: fixtures.url(for: "test.zip"))
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
