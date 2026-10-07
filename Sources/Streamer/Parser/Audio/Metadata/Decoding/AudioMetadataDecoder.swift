//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Decodes the values of audio tags.
///
/// https://github.com/readium/architecture/blob/master/streamer/parser/audio-metadata.md#value-decoding
struct AudioMetadataDecoder {
    /// Values of an ID3 text frame feeding a field with several values, which
    /// may be joined with `/`.
    ///
    /// An MP4 value is never split.
    func id3Values(from string: String) -> [String] {
        string.trimmedParts(separatedBy: ["/"])
    }

    /// Genres of a tag, which may list several of them separated by `;` or
    /// `/`.
    func genres(from string: String) -> [String] {
        string.trimmedParts(separatedBy: [";", "/"])
    }

    /// Genres of an ID3 `TCON` frame, without its references to the ID3v1 genre
    /// list, which holds music genres.
    ///
    /// A reference is written `(17)` in ID3v2.3, where several of them may
    /// precede a name as in `(12)(101)Fantasy`, and `17` in ID3v2.4. A name
    /// starting with a parenthesis is escaped as `((name)`.
    func id3Genres(from string: String) -> [String] {
        genres(from: string).compactMap { genre in
            var name = Substring(genre)

            while
                name.hasPrefix("("),
                let end = name.firstIndex(of: ")"),
                name[..<end].dropFirst().isID3GenreReference
            {
                name = name[end...].dropFirst().drop(while: \.isWhitespace)
            }

            if name.hasPrefix("((") {
                name = name.dropFirst()
            } else if name.isID3GenreReference {
                return nil
            }

            return name.trimmingCharacters(in: .whitespacesAndNewlines).orNilIfEmpty()
        }
    }

    /// Position in a series, which may be decimal such as `2.5`.
    ///
    /// A value which is not a number is ignored. This includes the `2/5` of
    /// an ID3 `MVIN` frame, which the reader of that frame has to split.
    func seriesPosition(from string: String) -> Double? {
        let string = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard string.matches(#"^[0-9]+(\.[0-9]+)?$"#) else {
            return nil
        }
        return Double(string)
    }

    /// Date of a tag holding a year (`2021`), a year and month (`2021-03`), a
    /// date (`2021-03-04`) or an ISO 8601 timestamp.
    ///
    /// A missing component takes its earliest value, in UTC.
    func date(from string: String) -> Date? {
        var string = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // A timestamp may stop at the hour or at the minute, as in ID3v2.4,
        // and may separate the date from the time with a space.
        if let separator = string.dropFirst(10).first, separator == "T" || separator == " " {
            let timeAndZone = string.dropFirst(11)
            let zoneStart = timeAndZone.firstIndex { "Z+-".contains($0) } ?? timeAndZone.endIndex
            var time = String(timeAndZone[..<zoneStart])
            switch time.count {
            case 2: time += ":00:00"
            case 5: time += ":00"
            default: break
            }
            string = "\(string.prefix(10))T\(time)\(timeAndZone[zoneStart...])"
        }

        return string.dateFromISO8601
    }

    /// BCP 47 language tag of a tag holding a BCP 47 tag (`fr-CA`) or an
    /// ISO 639 code (`fra`, `fre`), using the two-letter code when one exists.
    ///
    /// `und` and any other value, such as a language name, are ignored.
    func language(from string: String) -> String? {
        let string = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // `Locale` is too lenient to validate the value: it turns "English"
        // into `en`.
        guard string.matches(#"^[A-Za-z]{2,3}([-_][A-Za-z0-9]{1,8})*$"#) else {
            return nil
        }

        let language = Locale.canonicalLanguageIdentifier(from: string)
        guard
            let code = language.split(separator: "-").first.map(String.init),
            code != "und",
            Locale.isoLanguageCodeSet.contains(code)
        else {
            return nil
        }
        return language
    }

    /// Chapters of the content of a Nero `chpl` atom, ordered by start time.
    ///
    /// The atom holds no duration: a chapter runs to the start of the next
    /// one, and the last one to the end of the file.
    ///
    /// Reading stops at the first chapter which is truncated. An atom of an
    /// unknown version has no chapters.
    ///
    /// - Parameter fileDuration: Duration of the audio file in seconds.
    func neroChapters(from data: Data, fileDuration: TimeInterval?) -> [AudioMetadata.Chapter] {
        var bytes = data

        // Version (1 byte), flags (3 bytes), 4 reserved bytes when the version
        // is 1, chapter count (1 byte).
        guard
            let version = bytes.popFirst(),
            let skippedCount = [0: 3, 1: 7][version],
            bytes.popFirst(skippedCount) != nil,
            let count = bytes.popFirst()
        else {
            return []
        }

        var chapters: [AudioMetadata.Chapter] = []
        for _ in 0 ..< count {
            // Start (64-bit big endian, in units of 100 ns), title length
            // (1 byte), title (UTF-8).
            guard
                let start = bytes.popFirst(8),
                let titleLength = bytes.popFirst(),
                let title = bytes.popFirst(Int(titleLength))
            else {
                break
            }

            chapters.append(AudioMetadata.Chapter(
                title: String(data: title, encoding: .utf8)?.orNilIfBlank(),
                start: TimeInterval(start.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }) / 10_000_000
            ))
        }

        chapters.sort { $0.start < $1.start }

        for index in chapters.indices {
            let end = chapters.indices.contains(index + 1) ? chapters[index + 1].start : fileDuration
            if let end, end > chapters[index].start {
                chapters[index].duration = end - chapters[index].start
            }
        }

        return chapters
    }
}

private extension Substring {
    /// Whether this is a reference to the ID3v1 genre list, as written in a
    /// `TCON` frame: the index of a genre, `RX` for a remix or `CR` for a
    /// cover.
    var isID3GenreReference: Bool {
        self == "RX" || self == "CR" || (!isEmpty && allSatisfy(("0" ... "9").contains))
    }
}

private extension Locale {
    static let isoLanguageCodeSet = Set(isoLanguageCodes)
}

private extension String {
    /// Whether the string matches the given regular expression.
    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }

    /// Splits the string on the given `separators`, then trims each part and
    /// drops the blank ones.
    func trimmedParts(separatedBy separators: Set<Character>) -> [String] {
        split(whereSeparator: separators.contains)
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).orNilIfEmpty() }
    }
}

private extension Data {
    /// Removes and returns the first `count` bytes, or nil when there are not
    /// enough of them.
    mutating func popFirst(_ count: Int) -> Data? {
        guard count <= self.count else {
            return nil
        }
        defer { removeFirst(count) }
        return prefix(count)
    }
}
