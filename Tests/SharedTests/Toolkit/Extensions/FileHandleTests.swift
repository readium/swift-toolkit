//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum FileHandleTests {
    struct Stream {
        private let file = Fixtures(path: "Archive").url(for: "exploded/uncompressed.txt")

        @Test(arguments: [
            (0 ..< 30, ["This conte", "nt is unco", "mpressed.\n"]),
            (4 ..< 19, [" content i", "s unc"]),
            // A range overlapping the end of the file is clamped.
            (25 ..< 100, ["sed.\n"]),
            (30 ..< 100, []),
            (4 ..< 4, []),
        ] as [(Range<UInt64>, [String])])
        func deliversTheRangeInChunks(range: Range<UInt64>, expected: [String]) async throws {
            let handle = try FileHandle(forReadingFrom: file.url)
            let chunks = Mutex<[String]>([])

            try await handle.stream(range: range, chunkSize: 10) { chunk in
                chunks.withLock { $0.append(String(decoding: chunk, as: UTF8.self)) }
            }.get()

            #expect(chunks.withLock { $0 } == expected)
        }

        @Test func doesNotMoveTheOffsetOfTheHandle() async throws {
            let handle = try FileHandle(forReadingFrom: file.url)
            try handle.seek(toOffset: 4)

            try await handle.stream(range: 12 ..< 30) { _ in }.get()

            #expect(try handle.offset() == 4)
        }

        @Test func failsWhenTheBytesCannotBeReadAtTheirPosition() async {
            let result = await Pipe().fileHandleForReading.stream(range: 0 ..< 10) { _ in
                Issue.record("Received a chunk from a pipe")
            }

            guard case .failure(.access(.fileSystem(.io))) = result else {
                Issue.record("Expected .failure(.access(.fileSystem(.io))), got \(result)")
                return
            }
        }
    }
}
