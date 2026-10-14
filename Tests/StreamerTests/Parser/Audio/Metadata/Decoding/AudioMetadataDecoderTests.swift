//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumStreamer
import Testing

enum AudioMetadataDecoderTests {
    struct ID3Values {
        @Test(arguments: [
            ("Alice", ["Alice"]),
            ("Alice/Bob", ["Alice", "Bob"]),
            (" Alice / Bob ", ["Alice", "Bob"]),
            ("Alice//Bob/", ["Alice", "Bob"]),
            // Any other punctuation is part of the value.
            ("Alice, Bob; Carol & Dave", ["Alice, Bob; Carol & Dave"]),
            ("", []),
            (" / ", []),
        ] as [(String, [String])])
        func splitsOnSlashes(value: String, expected: [String]) {
            #expect(decoder.id3Values(from: value) == expected)
        }
    }

    struct Genres {
        @Test(arguments: [
            ("Fantasy", ["Fantasy"]),
            ("Fantasy; Adventure/Epic", ["Fantasy", "Adventure", "Epic"]),
            (" Fantasy //Epic;; ", ["Fantasy", "Epic"]),
            // Any other punctuation is part of the genre.
            ("Sci-Fi, Fantasy & Horror", ["Sci-Fi, Fantasy & Horror"]),
            // Only an ID3 genre holds references.
            ("(17)", ["(17)"]),
            ("", []),
        ] as [(String, [String])])
        func splitsOnSemicolonsAndSlashes(value: String, expected: [String]) {
            #expect(decoder.genres(from: value) == expected)
        }
    }

    struct ID3Genres {
        @Test(arguments: [
            // ID3v2.3 references.
            ("(183)", []),
            ("(12)Fantasy", ["Fantasy"]),
            ("(12)(101) Fantasy ", ["Fantasy"]),
            ("(12) (101) Fantasy", ["Fantasy"]),
            ("(RX)(CR)", []),
            // ID3v2.4 references.
            ("183", []),
            ("RX", []),
            ("CR", []),
            // Several values, as joined when saving ID3v2.3.
            ("183/Fantasy; (12)", ["Fantasy"]),
            // A name starting with a parenthesis is escaped.
            ("((Live) Recording", ["(Live) Recording"]),
            ("(12)((Live)", ["(Live)"]),
            ("((12)", ["(12)"]),
            // Not a reference.
            ("(Live) Recording", ["(Live) Recording"]),
            ("()", ["()"]),
            ("(12", ["(12"]),
            ("1984 Stories", ["1984 Stories"]),
            ("１７", ["１７"]),
            ("", []),
        ] as [(String, [String])])
        func ignoresReferences(value: String, expected: [String]) {
            #expect(decoder.id3Genres(from: value) == expected)
        }
    }

    struct SeriesPositions {
        @Test(arguments: [
            ("2", 2),
            ("2.5", 2.5),
            ("0", 0),
            ("02", 2),
            (" 3 ", 3),
        ] as [(String, Double)])
        func decodesANumber(value: String, expected: Double) {
            #expect(decoder.seriesPosition(from: value) == expected)
        }

        @Test(arguments: [
            "",
            "two",
            "2,5",
            "2.5.1",
            // The form of an ID3 `MVIN` frame, left to the reader of that
            // frame.
            "2/5",
            // Accepted by `Double`.
            "-1",
            "+1",
            ".5",
            "2.",
            "1e3",
            "0x10",
        ])
        func ignoresAnyOtherValue(value: String) {
            #expect(decoder.seriesPosition(from: value) == nil)
        }
    }

    struct Dates {
        @Test(arguments: [
            (" 2021 ", "2021-01-01T00:00:00Z"),
            // A timestamp stopping at the hour or at the minute, with or
            // without a time zone.
            ("2021-03-04T10", "2021-03-04T10:00:00Z"),
            ("2021-03-04T10:20", "2021-03-04T10:20:00Z"),
            ("2021-03-04T10Z", "2021-03-04T10:00:00Z"),
            ("2021-03-04T10:20+02:00", "2021-03-04T08:20:00Z"),
            ("2021-03-04T10:20-05:00", "2021-03-04T15:20:00Z"),
            // A complete timestamp.
            ("2021-03-04T10:20:30-05:00", "2021-03-04T15:20:30Z"),
            // A space between the date and the time.
            ("2021-03-04 10:20:30", "2021-03-04T10:20:30Z"),
            // A date with a time zone has no time to complete.
            ("2021-03-04+02:00", "2021-03-03T22:00:00Z"),
        ])
        func decodesADateOrATimestamp(value: String, expected: String) {
            #expect(decoder.date(from: value) == ISO8601DateFormatter().date(from: expected)!)
        }

        @Test(arguments: [
            "",
            "March 2021",
            "2021-03-04T",
        ])
        func ignoresAnyOtherValue(value: String) {
            #expect(decoder.date(from: value) == nil)
        }
    }

    struct Languages {
        @Test(arguments: [
            ("fr", "fr"),
            // ISO 639-2 terminology and bibliographic codes.
            ("fra", "fr"),
            ("fre", "fr"),
            // An ISO 639 code without a two-letter form.
            ("gsw", "gsw"),
            // BCP 47 tags with subtags.
            ("fr-CA", "fr-CA"),
            ("es-419", "es-419"),
            ("zh-Hans-CN", "zh-Hans-CN"),
            // Any case, separator and surrounding whitespace.
            ("FRA", "fr"),
            ("fr_CA", "fr-CA"),
            (" eng ", "en"),
        ])
        func convertsToBCP47(value: String, expected: String) {
            #expect(decoder.language(from: value) == expected)
        }

        @Test(arguments: [
            "",
            "und",
            // Not an ISO 639 code. ID3 uses `XXX` for an unknown language.
            "xx",
            "XXX",
            // Not shaped as a language tag, but accepted by `Locale`.
            "English",
            "fr-",
            "fr-123456789",
        ])
        func ignoresAnyOtherValue(value: String) {
            #expect(decoder.language(from: value) == nil)
        }
    }

    struct NeroChapters {
        typealias Chapter = AudioMetadata.Chapter

        @Test func decodesAnAtomWrittenByFFmpeg() {
            let atom = Data([
                // Version, flags, reserved bytes, chapter count.
                0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
                // 0 s, "Opening"
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07,
                0x4F, 0x70, 0x65, 0x6E, 0x69, 0x6E, 0x67,
                // 1 s, "Chapitre deux é"
                0x00, 0x00, 0x00, 0x00, 0x00, 0x98, 0x96, 0x80, 0x10,
                0x43, 0x68, 0x61, 0x70, 0x69, 0x74, 0x72, 0x65, 0x20, 0x64, 0x65, 0x75, 0x78, 0x20, 0xC3, 0xA9,
                // 2.5 s, without a title
                0x00, 0x00, 0x00, 0x00, 0x01, 0x7D, 0x78, 0x40, 0x00,
            ])

            #expect(decoder.neroChapters(from: atom, fileDuration: 3) == [
                Chapter(title: "Opening", start: 0, duration: 1),
                Chapter(title: "Chapitre deux é", start: 1, duration: 1.5),
                Chapter(title: nil, start: 2.5, duration: 0.5),
            ])
        }

        @Test func version0HasNoReservedBytes() {
            let atom = chpl(version: 0, [(0, "One"), (3600, "Two")])

            #expect(decoder.neroChapters(from: atom, fileDuration: 7200) == [
                Chapter(title: "One", start: 0, duration: 3600),
                Chapter(title: "Two", start: 3600, duration: 3600),
            ])
        }

        @Test func unknownVersionHasNoChapters() {
            let atom = chpl(version: 2, [(0, "One")])

            #expect(decoder.neroChapters(from: atom, fileDuration: 30) == [])
        }

        @Test func ordersByStartTime() {
            let atom = chpl([(7200, "Three"), (0, "One"), (3600, "Two")])

            #expect(decoder.neroChapters(from: atom, fileDuration: 10800) == [
                Chapter(title: "One", start: 0, duration: 3600),
                Chapter(title: "Two", start: 3600, duration: 3600),
                Chapter(title: "Three", start: 7200, duration: 3600),
            ])
        }

        @Test(arguments: [nil, 10, 5] as [TimeInterval?])
        func lastChapterHasNoDurationWithoutALaterEndOfFile(fileDuration: TimeInterval?) {
            let atom = chpl([(0, "One"), (10, "Two")])

            #expect(decoder.neroChapters(from: atom, fileDuration: fileDuration) == [
                Chapter(title: "One", start: 0, duration: 10),
                Chapter(title: "Two", start: 10),
            ])
        }

        @Test func chapterHasNoDurationWhenTheNextOneStartsAtTheSameTime() {
            let atom = chpl([(0, "One"), (0, "Two")])

            // Which of the two comes first is not specified.
            #expect(decoder.neroChapters(from: atom, fileDuration: 30).map(\.duration) == [nil, 30])
        }

        /// A space, then a byte which is not UTF-8.
        @Test(arguments: [0x20, 0xFF] as [UInt8])
        func ignoresATitleWhichIsBlankOrNotUTF8(title: UInt8) {
            var atom = chpl([(0, "A")])
            atom[atom.count - 1] = title

            #expect(decoder.neroChapters(from: atom, fileDuration: nil) == [Chapter(start: 0)])
        }

        @Test func ignoresTheChaptersAfterTheDeclaredCount() {
            let atom = chpl(count: 1, [(0, "One"), (10, "Two")])

            #expect(decoder.neroChapters(from: atom, fileDuration: 30) == [
                Chapter(title: "One", start: 0, duration: 30),
            ])
        }

        /// The atom is 33 bytes long: a header of 9 bytes, then two chapters
        /// of 12 bytes each.
        @Test(arguments: [
            // Cut in the header.
            (0, 0),
            (8, 0),
            // A header without a chapter.
            (9, 0),
            // Cut in the start, the title length and the title of a chapter.
            (16, 0),
            (17, 0),
            (20, 0),
            (21, 1),
            (32, 1),
            (33, 2),
        ])
        func stopsAtTheFirstTruncatedChapter(length: Int, expectedCount: Int) {
            let atom = chpl([(0, "One"), (10, "Two")])

            #expect(decoder.neroChapters(from: atom.prefix(length), fileDuration: 30).count == expectedCount)
        }

        @Test func decodesASliceOfData() {
            let atom = Data([0xFF, 0xFF]) + chpl([(0, "One")])

            #expect(decoder.neroChapters(from: atom.dropFirst(2), fileDuration: 30) == [
                Chapter(title: "One", start: 0, duration: 30),
            ])
        }
    }
}

// MARK: - Helpers

private let decoder = AudioMetadataDecoder()

/// Builds the content of a `chpl` atom holding the given chapters, whose
/// start times are in seconds.
///
/// - Parameter count: Declared number of chapters, when it is not the actual
///   one.
private func chpl(version: UInt8 = 1, count: Int? = nil, _ chapters: [(start: UInt64, title: String)]) -> Data {
    var data = Data([version, 0, 0, 0])
    if version != 0 {
        data += Data(count: 4)
    }
    data.append(UInt8(count ?? chapters.count))
    for chapter in chapters {
        let title = Data(chapter.title.utf8)
        withUnsafeBytes(of: (chapter.start * 10_000_000).bigEndian) { data.append(contentsOf: $0) }
        data.append(UInt8(title.count))
        data += title
    }
    return data
}
