//
//  ZIPTests.swift
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

struct ZIPTester<Archive: ZIPArchive> {

    func testOpenSuccess() {
        XCTAssertNoThrow(try Archive(file: fixtures.url(for: "test.zip")))
    }

    func testOpenNotFound() {
        XCTAssertThrowsError(try Archive(file: fixtures.url(for: "unknown.zip"))) { error in
            XCTAssertEqual(error as? ZIPError, ZIPError.openFailed)
        }
    }
    
    func testOpenNotAZIP() {
        XCTAssertThrowsError(try Archive(file: fixtures.url(for: "not-a.zip"))) { error in
            XCTAssertEqual(error as? ZIPError, ZIPError.openFailed)
        }
    }
    
    func testGetNonExistingEntry() {
        let archive = try! Archive(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "unknown")
        XCTAssertNil(entry)
    }

    func testGetFileEntry() {
        let archive = try! Archive(file: fixtures.url(for: "test.zip"))
        XCTAssertEqual(
            archive.entry(at: "A folder/wasteland-cover.jpg"),
            ZIPEntry(
                path: "A folder/wasteland-cover.jpg",
                isDirectory: false,
                length: 103477,
                compressedLength: 82374
            )
        )
    }

    func testGetUncompressedFileEntry() {
        let archive = try! Archive(file: fixtures.url(for: "test.zip"))
        XCTAssertEqual(
            archive.entry(at: "uncompressed.jpg"),
            ZIPEntry(
                path: "uncompressed.jpg",
                isDirectory: false,
                length: 279551,
                compressedLength: 279551
            )
        )
    }

    func testGetDirectoryEntry() {
        let archive = try! Archive(file: fixtures.url(for: "test.zip"))
        XCTAssertNil(archive.entry(at: "A folder"))
        XCTAssertEqual(
            archive.entry(at: "A folder/"),
            ZIPEntry(
                path: "A folder/",
                isDirectory: true,
                length: 0,
                compressedLength: 0
            )
        )
    }
    
    func testGetEntries() {
        let archive = try! Archive(file: fixtures.url(for: "test.zip"))
        XCTAssertEqual(archive.entries, [
            ZIPEntry(path: ".hidden", isDirectory: false, length: 0, compressedLength: 0),
            ZIPEntry(path: "A folder/", isDirectory: true, length: 0, compressedLength: 0),
            ZIPEntry(path: "A folder/Sub.folder%/", isDirectory: true, length: 0, compressedLength: 0),
            ZIPEntry(path: "A folder/Sub.folder%/file.txt", isDirectory: false, length: 20, compressedLength: 20),
            ZIPEntry(path: "A folder/wasteland-cover.jpg", isDirectory: false, length: 103477, compressedLength: 82374),
            ZIPEntry(path: "root.txt", isDirectory: false, length: 0, compressedLength: 0),
            ZIPEntry(path: "uncompressed.jpg", isDirectory: false, length: 279551, compressedLength: 279551),
            ZIPEntry(path: "uncompressed.txt", isDirectory: false, length: 30, compressedLength: 30)
        ])
    }

    func testReadCompressedEntry() {
        let archive = try! Archive(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "A folder/Sub.folder%/file.txt")!
        let data = archive.read(at: entry.path)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            "I'm inside\nthe ZIP.\n"
        )
    }
    
    func testReadUncompressedEntry() {
        let archive = try! Archive(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "uncompressed.txt")!
        let data = archive.read(at: entry.path)
        XCTAssertNotNil(data)
        XCTAssertEqual(
            String(data: data!, encoding: .utf8),
            "This content is uncompressed.\n"
        )
    }
    
    func testReadRange() {
        let archive = try! Archive(file: fixtures.url(for: "test.zip"))
        let entry = archive.entry(at: "A folder/Sub.folder%/file.txt")!
        let data = archive.read(at: entry.path, range: (entry.length - 6)..<entry.length)
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
//    func testReadRange() { tester.testReadRange() }
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
    func testReadRange() { tester.testReadRange() }
    
}

class ZIPBenchmarkingTests: XCTestCase {
    
    func testCompareRange() {
        let archives: [ZIPArchive] = [
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
