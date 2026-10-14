//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum ZIPFoundationContainerTests {
    struct Opening {
        @Test func failsWhenTheFileIsMissing() async {
            let result = await ZIPFoundationContainer.make(resource: FileResource(file: fixtures.url(for: "unknown.zip")))
            guard case .failure(.reading(.access(.fileSystem(.fileNotFound)))) = result else {
                Issue.record("Expected a file not found error, got \(result)")
                return
            }
        }

        @Test func failsWhenTheFileIsNotAZIP() async {
            let result = await ZIPFoundationContainer.make(resource: FileResource(file: fixtures.url(for: "not-a.zip")))
            guard case .failure(.reading(.decoding)) = result else {
                Issue.record("Expected .failure(.reading(.decoding)), got \(result)")
                return
            }
        }
    }

    struct Entries {
        @Test func listsTheFilesOfTheArchive() async throws {
            let container = try await container(for: "test.zip")

            #expect(
                container.entries == Set([
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

        @Test func unknownEntryIsNil() async throws {
            let container = try await container(for: "test.zip")
            #expect(container[AnyURL(path: "unknown")!] == nil)
        }

        @Test(arguments: [
            (".hidden", false, 0, 0),
            ("A folder/Sub.folder%/file.txt", false, 20, 20),
            ("A folder/wasteland-cover.jpg", true, 82374, 103_477),
            ("root.txt", false, 0, 0),
            ("uncompressed.jpg", false, 279_551, 279_551),
            ("uncompressed.txt", false, 30, 30),
            ("A folder/Sub.folder%/file-compressed.txt", true, 8659, 29609),
        ] as [(String, Bool, UInt64, UInt64)])
        func exposesTheLengthAndProperties(path: String, isCompressed: Bool, length: UInt64, originalLength: UInt64) async throws {
            let resource = try await entry(path)

            #expect(try await resource.estimatedLength().get() == originalLength)

            let properties = try await resource.properties().get()
            #expect(properties.archive == ArchiveProperties(entryLength: length, isEntryCompressed: isCompressed))
            #expect(properties.filename == RelativeURL(path: path)!.lastPathSegment)
        }

        /// Some archives (notably CBZ comics) carry spec-noncompliant entry
        /// names with a leading slash (e.g. `/001.jpg`). APPNOTE 4.4.17.1
        /// mandates entry names be relative, so they must be normalized to
        /// slash-free relative URLs.
        @Test func leadingSlashIsNormalized() async throws {
            let container = try await container(for: "leading-slash.zip")

            #expect(
                container.entries == Set([
                    AnyURL(path: "root.txt")!,
                    AnyURL(path: "folder/file.txt")!,
                    AnyURL(path: "normal.txt")!,
                ])
            )

            let data = try await entry("root.txt", in: "leading-slash.zip").read().get()
            #expect(String(data: data, encoding: .utf8) == "I am at the forged root.\n")
        }
    }

    struct Reading {
        @Test(arguments: LargeEntry.allCases)
        fileprivate func readsTheWholeEntry(_ largeEntry: LargeEntry) async throws {
            let data = try await entry(largeEntry.rawValue).read().get()
            #expect(data == largeEntry.data)
        }

        @Test(arguments: [
            ("A folder/Sub.folder%/file.txt", 14 ..< 20, " ZIP.\n"),
            ("A folder/Sub.folder%/file-compressed.txt", 14 ..< 20, " ZIP.\n"),
            // Out-of-range indexes must be clamped per the `Streamable`
            // contract.
            ("A folder/Sub.folder%/file.txt", 14 ..< 40, " ZIP.\n"),
            ("A folder/Sub.folder%/file-compressed.txt", 29600 ..< 29700, "r ipsum.\n"),
            ("A folder/Sub.folder%/file.txt", 100 ..< 200, ""),
            ("A folder/Sub.folder%/file-compressed.txt", 40000 ..< 40100, ""),
            (".hidden", 0 ..< 10, ""),
        ] as [(String, Range<UInt64>, String)])
        func readsARange(path: String, range: Range<UInt64>, expected: String) async throws {
            let data = try await entry(path).read(range: range).get()
            #expect(String(data: data, encoding: .utf8) == expected)
        }

        @Test(arguments: LargeEntry.allCases)
        fileprivate func readsSeveralRangesOfTheSameEntry(_ largeEntry: LargeEntry) async throws {
            let resource = try await entry(largeEntry.rawValue)
            let data = largeEntry.data

            for range in [60000 ..< 60100, 10 ..< 50, 100_000 ..< 103_477, 0 ..< 1, 40000 ..< 90000] as [Range<UInt64>] {
                #expect(try await resource.read(range: range).get() == data[Int(range.lowerBound) ..< Int(range.upperBound)])
            }
        }
    }
}

// MARK: - Helpers

private let fixtures = Fixtures(path: "Archive")

/// The large entries of `test.zip`, whose content is also in the `exploded`
/// directory.
private enum LargeEntry: String, CaseIterable {
    case stored = "uncompressed.jpg"
    case deflated = "A folder/wasteland-cover.jpg"

    var data: Data {
        fixtures.data(at: "exploded/\(rawValue)")
    }
}

private func container(for filename: String) async throws -> Container {
    try await ZIPFoundationContainer.make(resource: FileResource(file: fixtures.url(for: filename))).get()
}

private func entry(_ path: String, in filename: String = "test.zip") async throws -> Resource {
    try await #require(container(for: filename)[AnyURL(path: path)!])
}
