//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing
import TestSupport

enum MinizipContainerTests {
    struct Opening {
        @Test func failsWhenTheFileIsMissing() async {
            let result = await MinizipContainer.make(file: fixtures.url(for: "unknown.zip"))
            guard case .failure(.reading(.access(.fileSystem(.fileNotFound)))) = result else {
                Issue.record("Expected a file not found error, got \(result)")
                return
            }
        }

        @Test func failsWhenTheFileIsNotAZIP() async {
            let result = await MinizipContainer.make(file: fixtures.url(for: "not-a.zip"))
            guard case .failure(.notAZIP) = result else {
                Issue.record("Expected .failure(.notAZIP), got \(result)")
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

        /// Some archives carry spec-noncompliant entry names with a leading
        /// slash (e.g. `/001.jpg`). APPNOTE 4.4.17.1 mandates entry names be
        /// relative, so they must be normalized to slash-free relative URLs.
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

        /// The ranges go forward and backward, as a compressed entry keeps its
        /// position between two reads: a range after it is reached from
        /// there, and a range before it from the start of the entry.
        @Test(arguments: LargeEntry.allCases)
        fileprivate func readsSeveralRangesOfTheSameEntry(_ largeEntry: LargeEntry) async throws {
            let resource = try await entry(largeEntry.rawValue)
            let data = largeEntry.data

            for range in [60000 ..< 60100, 10 ..< 50, 100_000 ..< 103_477, 0 ..< 1, 40000 ..< 90000] as [Range<UInt64>] {
                #expect(try await resource.read(range: range).get() == data[Int(range.lowerBound) ..< Int(range.upperBound)])
            }
        }

        /// `corrupted.zip` holds a single deflated entry, whose compressed data
        /// was partly overwritten so that it cannot be inflated.
        @Test func corruptedCompressedEntryFails() async throws {
            let result = try await entry("file.txt", in: "corrupted.zip").read()
            guard case .failure(.decoding) = result else {
                Issue.record("Expected .failure(.decoding), got \(result)")
                return
            }
        }
    }

    struct Streaming {
        @Test(arguments: LargeEntry.allCases)
        fileprivate func deliversChunksOfTheChunkSize(_ largeEntry: LargeEntry) async throws {
            let (result, chunks) = try await streamChunks(of: entry(largeEntry.rawValue))

            try result.get()
            let length = largeEntry.data.count
            let chunkSize = largeEntry.chunkSize
            #expect(chunks.map(\.count) == Array(repeating: chunkSize, count: length / chunkSize) + [length % chunkSize])
        }

        @Test(arguments: LargeEntry.allCases, [0, 1])
        fileprivate func stopsWhenTheTaskIsCancelled(_ largeEntry: LargeEntry, afterChunkCount: Int) async throws {
            let resource = try await entry(largeEntry.rawValue)

            let (result, chunks) = await Task {
                let cancel: @Sendable (Int) -> Void = { chunkCount in
                    if chunkCount == afterChunkCount {
                        withUnsafeCurrentTask { $0?.cancel() }
                    }
                }
                cancel(0)
                return await streamChunks(of: resource, onChunk: cancel)
            }.value

            #expect(chunks.count == afterChunkCount)
            guard case .failure(.cancelled) = result else {
                Issue.record("Expected .failure(.cancelled), got \(result)")
                return
            }
        }

        @available(iOS 18.0, *)
        @Test func overlappingStreamsOfAStoredEntryInterleave() async throws {
            let resource = try await entry(LargeEntry.stored.rawValue)
            let data = LargeEntry.stored.data

            let first = try await streamChunks(of: resource, holdingFirstChunkDuring: {
                await resource.read(range: 100 ..< 270_000)
            })

            #expect(first.bodyEndedDuringStream)
            #expect(try first.bodyResult.get() == data[100 ..< 270_000])
            try first.result.get()
            #expect(first.chunks.reduce(Data(), +) == data)
        }

        @Test func overlappingStreamsOfACompressedEntryRunOneAfterTheOther() async throws {
            let resource = try await entry(LargeEntry.deflated.rawValue)
            let data = LargeEntry.deflated.data

            // Identifier of the stream which delivered each chunk.
            let deliveries = Mutex<[Int]>([])
            let (firstChunks, continuation) = AsyncStream<Void>.makeStream()
            async let firstStream = streamChunks(of: resource) { chunkCount in
                deliveries.withLock { $0.append(1) }
                if chunkCount == 1 {
                    // Leaves the second stream the time to reach the entry
                    // while this one is running.
                    continuation.yield()
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
            try #require(await firstChunks.first(within: 5) != nil)
            let second = await streamChunks(of: resource) { _ in deliveries.withLock { $0.append(2) } }
            let first = await firstStream

            for (result, chunks) in [first, second] {
                try result.get()
                #expect(chunks.reduce(Data(), +) == data)
            }
            let chunkCount = first.chunks.count
            #expect(deliveries.withLock { $0 } == Array(repeating: 1, count: chunkCount) + Array(repeating: 2, count: chunkCount))
        }
    }

    struct Closing {
        @available(iOS 18.0, *)
        @Test func streamOfAStoredEntryEndsAfterClosing() async throws {
            let resource = try #require(try await entry(LargeEntry.stored.rawValue) as? MinizipResource)

            let stream = try await streamChunks(of: resource, holdingFirstChunkDuring: {
                await resource.doClose()
            })

            #expect(stream.bodyEndedDuringStream)
            try stream.result.get()
            #expect(stream.chunks.reduce(Data(), +) == LargeEntry.stored.data)
        }

        @Test(arguments: LargeEntry.allCases)
        fileprivate func readFailsAfterClosing(_ largeEntry: LargeEntry) async throws {
            let resource = try #require(try await entry(largeEntry.rawValue) as? MinizipResource)
            // Reads first, to close an entry which is opened.
            _ = try await resource.read(range: 0 ..< 1).get()

            await resource.doClose()

            let result = await resource.read()
            guard case .failure(.unsupportedOperation) = result else {
                Issue.record("Expected .failure(.unsupportedOperation), got \(result)")
                return
            }
        }
    }
}

// MARK: - Helpers

private let fixtures = Fixtures(path: "Archive")

/// The entries of `test.zip` spanning several chunks, whose content is also in
/// the `exploded` directory.
private enum LargeEntry: String, CaseIterable {
    case stored = "uncompressed.jpg"
    case deflated = "A folder/wasteland-cover.jpg"

    var data: Data {
        fixtures.data(at: "exploded/\(rawValue)")
    }

    /// Maximum length of the chunks it is streamed in.
    var chunkSize: Int {
        switch self {
        case .stored: 256 * 1024
        case .deflated: 32 * 1024
        }
    }
}

private func container(for filename: String) async throws -> Container {
    try await MinizipContainer.make(file: fixtures.url(for: filename)).get()
}

private func entry(_ path: String, in filename: String = "test.zip") async throws -> Resource {
    try await #require(container(for: filename)[AnyURL(path: path)!])
}

/// Streams the given `resource` and returns its chunks.
///
/// - Parameter onChunk: Called with the number of chunks received so far,
///   before the next one is read.
private func streamChunks(
    of resource: Resource,
    onChunk: @escaping @Sendable (Int) -> Void = { _ in }
) async -> (result: ReadResult<Void>, chunks: [Data]) {
    let chunks = Mutex<[Data]>([])
    let result = await resource.stream(range: nil) { chunk in
        onChunk(chunks.withLock {
            $0.append(chunk)
            return $0.count
        })
    }
    return (result, chunks.withLock { $0 })
}

/// Streams the given `resource`, holding the stream on its first chunk while
/// `body` runs.
///
/// The stream runs on its own thread, as holding it blocks its thread. On a
/// thread of the cooperative pool, it could starve `body`.
///
/// `bodyEndedDuringStream` tells whether `body` ended while the stream was
/// held, and not because the stream gave up waiting for it.
@available(iOS 18.0, *)
private func streamChunks<T>(
    of resource: Resource,
    holdingFirstChunkDuring body: () async -> T
) async throws -> (result: ReadResult<Void>, chunks: [Data], bodyResult: T, bodyEndedDuringStream: Bool) {
    let (firstChunks, continuation) = AsyncStream<Void>.makeStream()
    let bodyEnded = DispatchSemaphore(value: 0)
    let bodyEndedDuringStream = Mutex(false)
    let stream = Task(executorPreference: DispatchQueueTaskExecutor()) {
        await streamChunks(of: resource) { chunkCount in
            guard chunkCount == 1 else {
                return
            }
            continuation.yield()
            let waited = bodyEnded.wait(timeout: .now() + holdTimeout)
            bodyEndedDuringStream.withLock { $0 = (waited == .success) }
        }
    }

    try #require(await firstChunks.first(within: holdTimeout) != nil)
    let bodyResult = await body()
    bodyEnded.signal()
    let (result, chunks) = await stream.value

    return (result, chunks, bodyResult, bodyEndedDuringStream.withLock { $0 })
}

/// Only reached when the stream prevents `body` from running, generous to
/// stand a busy machine.
private let holdTimeout: TimeInterval = 30

/// Runs the jobs of a task on a serial dispatch queue instead of the
/// cooperative pool.
@available(iOS 18.0, *)
private final class DispatchQueueTaskExecutor: TaskExecutor {
    private let queue = DispatchQueue(label: "org.readium.swift-toolkit.tests.task-executor")

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        queue.async {
            job.runSynchronously(on: self.asUnownedTaskExecutor())
        }
    }
}
