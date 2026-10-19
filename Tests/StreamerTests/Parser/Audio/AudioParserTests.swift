//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) import ReadiumShared
@testable import ReadiumStreamer
@_spi(ExperimentalTimeline) import TestSupport
import Testing

enum AudioParserTests {
    struct Formats {
        @Test func refusesNonAudioBased() async throws {
            let asset: Asset = try await .container(ZIPArchiveOpener().open(
                resource: FileResource(file: fixtures.url(for: "futuristic_tales.cbz")),
                format: Format(specifications: .zip, .informalComic, mediaType: .cbz, fileExtension: "cbz")
            ).get())

            let result = await AudioParser().parse(asset: asset, warnings: nil)

            guard case .failure(.formatNotSupported) = result else {
                Issue.record("Expected a formatNotSupported error, got \(result)")
                return
            }
        }
    }

    struct ZAB {
        let publication: Publication
        let warnings = ListWarningLogger()

        init() async throws {
            publication = try await AudioParser().parse(asset: zabAsset("audiotest.zab"), warnings: warnings).get().build()
        }

        /// The reading order is sorted alphabetically, ignores Thumbs.db,
        /// hidden files and non-audio files.
        ///
        /// The entries of `audiotest.zab` are compressed, and the default
        /// reader does not read them.
        @Test func readingOrderIsSortedAlphabeticallyWithoutMetadataOrCover() {
            #expect(publication.readingOrder == [
                Link(href: "Test%20Audiobook/gtr-jazz.mp3", mediaType: .mp3),
                Link(href: "Test%20Audiobook/Latin.mp3", mediaType: .mp3),
                Link(href: "Test%20Audiobook/vln-lin-cs.mp3", mediaType: .mp3),
            ])
            #expect(publication.linkWithRel(.cover) == nil)
            #expect(warnings.warnings.isEmpty)
        }

        @Test func hasNoPositions() async throws {
            let result = try await publication.positions().get()
            #expect(result.count == 0)
        }
    }

    /// With a reader recording its requests, on folders of files named
    /// `1.mp3`, `2.mp3` and so on.
    struct ReadingPolicy {
        /// Only a package whose source is a file is stored on the device.
        @Test(arguments: [
            (.never, .file, false),
            (.never, .remote, false),
            (.localOnly, .file, true),
            (.localOnly, .remote, false),
            (.localOnly, .unknown, false),
            (.always, .file, true),
            (.always, .remote, true),
            (.always, .unknown, true),
        ] as [(AudioParser.ContainerEntriesMetadataPolicy, FolderSource, Bool)])
        func readsTheEntriesOfAPackageFollowingThePolicy(
            policy: AudioParser.ContainerEntriesMetadataPolicy,
            source: FolderSource,
            readsEntries: Bool
        ) async throws {
            let reader = FakeAudioMetadataReader { _ in .success(AudioMetadata(title: "Title")) }
            let parser = AudioParser(metadataReader: reader, config: .init(containerEntriesMetadataPolicy: policy))

            try await expectEntries(read: readsEntries, by: parser, reader: reader, source: source)
        }

        @Test(arguments: [(.file, true), (.remote, false)] as [(FolderSource, Bool)])
        func readsOnlyTheEntriesOfALocalPackageByDefault(source: FolderSource, readsEntries: Bool) async throws {
            let reader = FakeAudioMetadataReader { _ in .success(AudioMetadata(title: "Title")) }

            try await expectEntries(read: readsEntries, by: AudioParser(metadataReader: reader), reader: reader, source: source)
        }

        /// Expects `parser` to read both files of a folder, or none of them:
        /// the publication then has no title or table of contents, and its
        /// reading order holds bare links.
        private func expectEntries(
            read readsEntries: Bool,
            by parser: AudioParser,
            reader: FakeAudioMetadataReader,
            source: FolderSource
        ) async throws {
            let publication = try await withFolder(fileCount: 2, source: source) { folder in
                try await parser.parse(asset: folder, warnings: nil).get().build()
            }

            #expect(reader.requests.keys.sorted() == (readsEntries ? ["1.mp3", "2.mp3"] : []))
            #expect(publication.linkWithRel(.cover) == nil)

            let title = readsEntries ? "Title" : nil
            #expect(publication.manifest == Manifest(
                metadata: Metadata(conformsTo: [.audiobook], title: title),
                readingOrder: [
                    Link(href: "1.mp3", mediaType: .mp3, title: title),
                    Link(href: "2.mp3", mediaType: .mp3, title: title),
                ],
                tableOfContents: readsEntries
                    ? [Link(href: "1.mp3", title: "Title"), Link(href: "2.mp3", title: "Title")]
                    : []
            ))
        }

        @Test func alwaysReadsAStandaloneFile() async throws {
            let reader = FakeAudioMetadataReader { _ in .success(AudioMetadata(title: "Title")) }
            let parser = AudioParser(metadataReader: reader, config: .init(containerEntriesMetadataPolicy: .never))

            let publication = try await parser.parse(asset: fileAsset("audio/tagged.mp3"), warnings: nil).get().build()

            #expect(reader.requests == ["tagged.mp3": [true]])
            #expect(publication.readingOrder == [Link(href: "publication.mp3", mediaType: .mp3, title: "Title")])
        }

        /// A batch of three files, the default, asks for the covers only
        /// while none was found, and the cover is the first one in reading
        /// order.
        @Test(arguments: [
            // In the first batch, which holds two of them.
            ([3, 2], 3, 2),
            // In the second batch only.
            ([5], 6, 5),
            // In no file.
            ([], 10, nil),
        ] as [([Int], Int, Int?)])
        func asksForTheCoversUntilABatchHoldsOne(filesWithCover: [Int], lastFileAskedForCover: Int, expectedCover: Int?) async throws {
            let reader = FakeAudioMetadataReader { file in
                .success(AudioMetadata(
                    cover: filesWithCover.contains(file) ? AudioMetadata.Cover(data: Data("cover \(file)".utf8), mediaType: .png) : nil
                ))
            }

            let publication = try await withFolder(fileCount: 10) { folder in
                try await AudioParser(metadataReader: reader).parse(asset: folder, warnings: nil).get().build()
            }

            #expect(reader.requests == Dictionary(uniqueKeysWithValues: (1 ... 10).map { ("\($0).mp3", [$0 <= lastFileAskedForCover]) }))
            #expect(try await publication.coverBytes() == expectedCover.map { Data("cover \($0)".utf8) })
            #expect(publication.linkWithRel(.cover)?.mediaType == expectedCover.map { _ in .png })
        }

        /// Each read waits for the next one of its batch to complete, and the
        /// last one for the whole batch to have started. A deadline ends the
        /// waits when a batch does not run at the same time.
        @Test(arguments: [
            // Three files by default.
            (nil, 3),
            (4, 4),
            (1, 1),
            // One file at a time for a value below 1.
            (0, 1),
            (-1, 1),
        ] as [(Int?, Int)])
        func readsABatchOfFilesAtATimeAndKeepsTheReadingOrder(maxConcurrentMetadataReads: Int?, expectedBatchSize: Int) async throws {
            let fileCount = 6
            let startedFiles = Mutex<Set<Int>>([])
            let completedFiles = Mutex<Set<Int>>([])
            let reader = FakeAudioMetadataReader { file in
                startedFiles.withLock { _ = $0.insert(file) }
                let batchStart = (file - 1) / expectedBatchSize * expectedBatchSize + 1
                let batch = batchStart ... min(batchStart + expectedBatchSize - 1, fileCount)
                let deadline = Date().addingTimeInterval(5)
                while Date() < deadline {
                    let canComplete = file == batch.upperBound
                        ? startedFiles.withLock { $0.isSuperset(of: batch) }
                        : completedFiles.withLock { $0.contains(file + 1) }
                    if canComplete {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000)
                }
                completedFiles.withLock { _ = $0.insert(file) }
                return file % 2 == 0 ? .failure(.reading(.decoding("Truncated"))) : .success(AudioMetadata(title: "Title \(file)"))
            }
            let parser = AudioParser(
                metadataReader: reader,
                config: maxConcurrentMetadataReads.map { .init(maxConcurrentMetadataReads: $0) } ?? .init()
            )
            let warnings = ListWarningLogger()

            let publication = try await withFolder(fileCount: fileCount) { folder in
                try await parser.parse(asset: folder, warnings: warnings).get().build()
            }

            #expect(reader.maxConcurrentReadCount == expectedBatchSize)
            #expect(publication.readingOrder.map(\.title) == ["Title 1", nil, "Title 3", nil, "Title 5", nil])
            #expect(warnings.audioMetadataWarnings == [2, 4, 6].map {
                .undecodableMetadata(href: AnyURL(string: "\($0).mp3")!, reason: "DebugError(Truncated)")
            })
        }

        /// The last file holds an ISBN, whose warning comes from the manifest
        /// builder.
        @Test(arguments: [
            (.failure(.resourceNotSupported), []),
            (.failure(.reading(.decoding("Truncated"))), [.undecodableMetadata(href: AnyURL(string: "1.mp3")!, reason: "DebugError(Truncated)")]),
            (.success(AudioMetadata(isbn: "123")), [.invalidISBN(href: AnyURL(string: "1.mp3")!, isbn: "123")]),
        ] as [(Result<AudioMetadata, AudioMetadataReadError>, [AudioMetadataWarning])])
        func keepsABareLinkForAFileWithoutMetadata(result: Result<AudioMetadata, AudioMetadataReadError>, expectedWarnings: [AudioMetadataWarning]) async throws {
            let reader = FakeAudioMetadataReader { file in
                file == 1 ? result : .success(AudioMetadata(title: "Title"))
            }
            let warnings = ListWarningLogger()

            let publication = try await withFolder(fileCount: 2) { folder in
                try await AudioParser(metadataReader: reader).parse(asset: folder, warnings: warnings).get().build()
            }

            #expect(publication.readingOrder == [
                Link(href: "1.mp3", mediaType: .mp3),
                Link(href: "2.mp3", mediaType: .mp3, title: "Title"),
            ])
            #expect(warnings.audioMetadataWarnings == expectedWarnings)
        }

        /// The cancelled reads return a moment after their cancellation, as
        /// a reader waiting for its streams to end.
        @Test func accessFailureFailsTheOpeningOnceTheOtherReadsOfTheBatchAreCancelled() async throws {
            let reader = FakeAudioMetadataReader { file in
                guard file != 2 else {
                    return .failure(.reading(.access(.fileSystem(.forbidden(nil)))))
                }
                // The sleep ends when the task is cancelled.
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await withCheckedContinuation { continuation in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { continuation.resume() }
                }
                return .failure(.reading(.cancelled))
            }

            let result = try await withFolder(fileCount: 5) { folder in
                await AudioParser(metadataReader: reader).parse(asset: folder, warnings: nil)
            }

            guard case .failure(.reading(.access(.fileSystem(.forbidden)))) = result else {
                Issue.record("Expected a forbidden error, got \(result)")
                return
            }
            #expect(reader.cancelledFiles == [1, 3])
            #expect(reader.requests.keys.sorted() == ["1.mp3", "2.mp3", "3.mp3"])
        }
    }

    /// With a reader giving each file a duration of 100 s, on folders of
    /// files named `1.mp3`, `2.mp3` and so on.
    struct TimelineGeneration {
        struct Files: Sendable, CustomTestStringConvertible {
            let name: String
            var generatesTableOfContentsFromReadingOrder = true
            let metadata: [AudioMetadata]
            /// HREFs of the expected table of contents.
            let expectedTOC: [String]
            /// Outline of the expected timeline.
            let expectedTimeline: [String]

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            Files(
                name: "files with chapters",
                metadata: [
                    AudioMetadata(chapters: [.init(title: "One", start: 0), .init(title: "Two", start: 50)]),
                    AudioMetadata(chapters: [.init(title: "Three", start: 0)]),
                ],
                expectedTOC: ["1.mp3#t=0", "1.mp3#t=50", "2.mp3#t=0"],
                expectedTimeline: ["0 One → 1.mp3#t=0", "1 Two → 1.mp3#t=50", "2 Three → 2.mp3#t=0"]
            ),
            Files(
                name: "two titled files make the table of contents",
                metadata: [AudioMetadata(), AudioMetadata(title: "Two"), AudioMetadata(), AudioMetadata(title: "Four")],
                expectedTOC: ["2.mp3", "4.mp3"],
                expectedTimeline: ["0 Two → 2.mp3", "1 Four → 4.mp3"]
            ),
            Files(
                name: "a single titled file leaves the table of contents empty",
                metadata: [AudioMetadata(title: "One"), AudioMetadata()],
                expectedTOC: [],
                expectedTimeline: ["0 One → 1.mp3", "1 #2 → 2.mp3"]
            ),
            Files(
                name: "the option off disables both fallbacks",
                generatesTableOfContentsFromReadingOrder: false,
                metadata: [AudioMetadata(title: "One"), AudioMetadata(title: "Two")],
                expectedTOC: [],
                expectedTimeline: []
            ),
        ])
        func timelineFollowsTheTableOfContents(_ example: Files) async throws {
            let publication = try await parse(
                example.metadata,
                generatesTableOfContentsFromReadingOrder: example.generatesTableOfContentsFromReadingOrder
            )

            #expect(publication.manifest.tableOfContents.map(\.href) == example.expectedTOC)
            #expect(try await publication.timeline()?.outline == example.expectedTimeline)
        }

        @Test func untitledFileBelongsToThePrecedingItem() async throws {
            let publication = try await parse([AudioMetadata(), AudioMetadata(title: "Two"), AudioMetadata(), AudioMetadata(title: "Four")])
            let timeline = try #require(await publication.timeline())

            #expect(timeline.locate(Locator(href: AnyURL(string: "3.mp3")!, mediaType: .mp3)) == timeline.items[0])
            #expect(timeline.locate(Locator(href: AnyURL(string: "1.mp3")!, mediaType: .mp3)) == nil)
            #expect(timeline.segments(in: AnyURL(string: "1.mp3")!) == [])
        }

        /// Parses a folder of files having the given metadata, with a
        /// duration of 100 s.
        private func parse(_ files: [AudioMetadata], generatesTableOfContentsFromReadingOrder: Bool = true) async throws -> Publication {
            let reader = FakeAudioMetadataReader { file in
                var metadata = files[file - 1]
                metadata.duration = 100
                return .success(metadata)
            }
            let parser = AudioParser(metadataReader: reader, config: .init(generatesTableOfContentsFromReadingOrder: generatesTableOfContentsFromReadingOrder))

            return try await withFolder(fileCount: files.count) { folder in
                try await parser.parse(asset: folder, warnings: nil).get().build()
            }
        }
    }

    /// With the default reader, on the fixtures of `Fixtures/audio`.
    struct DefaultReader {
        @Test func readsAStandaloneFile() async throws {
            let publication = try await AudioParser().parse(asset: fileAsset("audio/tagged.m4b", mediaType: .mp4), warnings: nil).get().build()

            #expect(publication.metadata.title == "The Book")
            #expect(publication.metadata.authors.map(\.name) == ["Jane Author/Jill Author"])
            #expect(publication.metadata.duration?.rounded() == 3)
            #expect(publication.readingOrder.map(\.rounded) == [
                Link(href: "publication.m4b", mediaType: .mp4, title: "Part One", bitrate: 32, duration: 3),
            ])
            #expect(publication.manifest.tableOfContents.map(\.rounded) == [
                Link(href: "publication.m4b#t=0", title: "Opening", duration: 1),
                Link(href: "publication.m4b#t=1", title: "Chapitre deux é", duration: 1.5),
            ])
            #expect(try await publication.coverBytes() == fixtures.data(at: "audio/cover.jpg"))
        }

        /// The first file only has chapters, the second one only a title and
        /// a cover.
        @Test func readsTheFilesOfAFolder() async throws {
            let folder = Asset.container(ContainerAsset(
                container: DirectoryContainer(
                    directory: fixtures.url(for: "audio/"),
                    entries: [RelativeURL(string: "nero.m4b")!, RelativeURL(string: "tagged-v23.mp3")!]
                ),
                format: .folder
            ))

            let publication = try await AudioParser().parse(asset: folder, warnings: nil).get().build()

            #expect(publication.metadata.title == "Part 3")
            #expect(publication.metadata.duration?.rounded() == 6)
            #expect(publication.readingOrder.map(\.rounded) == [
                Link(href: "nero.m4b", mediaType: .mp4, bitrate: 32, duration: 3),
                Link(href: "tagged-v23.mp3", mediaType: .mp3, title: "Part 3", bitrate: 32, duration: 3),
            ])
            #expect(publication.manifest.tableOfContents.map(\.rounded) == [
                Link(href: "nero.m4b#t=0", title: "One", duration: 1.5),
                Link(href: "nero.m4b#t=1.5", title: "Two", duration: 1.5),
                Link(href: "tagged-v23.mp3", title: "Part 3", duration: 3),
            ])
            #expect(try await publication.coverBytes() == fixtures.data(at: "audio/cover.jpg"))
        }

        /// `mixed.zab` holds `tagged.m4b`, which is not compressed, then
        /// `tagged.mp3`, which is.
        @Test func readsOnlyTheEntriesOfAPackageWhichAreNotCompressed() async throws {
            let warnings = ListWarningLogger()

            let publication = try await AudioParser().parse(asset: zabAsset("audio/mixed.zab"), warnings: warnings).get().build()

            #expect(publication.metadata.title == "The Book")
            #expect(publication.readingOrder.map(\.rounded) == [
                Link(href: "tagged.m4b", mediaType: .mp4, title: "Part One", bitrate: 32, duration: 3),
                Link(href: "tagged.mp3", mediaType: .mp3),
            ])
            #expect(publication.manifest.tableOfContents.map(\.rounded) == [
                Link(href: "tagged.m4b#t=0", title: "Opening", duration: 1),
                Link(href: "tagged.m4b#t=1", title: "Chapitre deux é", duration: 1.5),
            ])
            #expect(try await publication.coverBytes() == fixtures.data(at: "audio/cover.jpg"))
            #expect(warnings.warnings.isEmpty)
        }

        @Test func cancelledTaskFailsWithCancelled() async {
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                let result = await AudioParser().parse(asset: fileAsset("audio/tagged.m4b", mediaType: .mp4), warnings: nil)
                guard case .failure(.reading(.cancelled)) = result else {
                    return false
                }
                return true
            }

            #expect(await task.value)
        }
    }
}

// MARK: - Helpers

private let fixtures = Fixtures()
private let assetRetriever = AssetRetriever(httpClient: DefaultHTTPClient())

/// Asset of a ZAB fixture.
private func zabAsset(_ fixture: String) async throws -> Asset {
    try await .container(ZIPArchiveOpener().open(
        resource: FileResource(file: fixtures.url(for: fixture)),
        format: Format(specifications: .zip, .informalAudiobook, mediaType: .zab, fileExtension: "zab")
    ).get())
}

/// Asset of a standalone audio fixture.
private func fileAsset(_ fixture: String, mediaType: MediaType = .mp3) -> Asset {
    let file = fixtures.url(for: fixture)
    return .resource(ResourceAsset(
        resource: FileResource(file: file),
        format: Format(
            specifications: mediaType.matches(.mp3) ? .mp3 : .mp4,
            mediaType: mediaType,
            fileExtension: file.pathExtension
        )
    ))
}

/// Where the container of a folder reports to come from.
enum FolderSource {
    /// The folder on the device.
    case file
    /// An HTTP URL.
    case remote
    /// No source URL.
    case unknown
}

/// A container reporting the given source URL.
private struct SourcedContainer: Container {
    let container: Container
    let sourceURL: AbsoluteURL?

    var entries: Set<AnyURL> {
        container.entries
    }

    subscript(url: any URLConvertible) -> Resource? {
        container[url]
    }
}

/// Calls `body` with the asset of a temporary folder holding `fileCount` empty
/// files, named `1.mp3`, `2.mp3` and so on.
private func withFolder<T>(fileCount: Int, source: FolderSource = .file, _ body: (Asset) async throws -> T) async throws -> T {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    for file in 1 ... fileCount {
        try Data().write(to: directory.appendingPathComponent("\(file).mp3"))
    }

    let folder = try await DirectoryContainer(directory: FileURL(url: directory)!)
    let container: Container = switch source {
    case .file: folder
    case .remote: SourcedContainer(container: folder, sourceURL: HTTPURL(string: "https://example.com/audiobook.zab")!)
    case .unknown: SourcedContainer(container: folder, sourceURL: nil)
    }

    return try await body(.container(ContainerAsset(container: container, format: .folder)))
}

/// A reader answering with `read`, which takes the number of a file named
/// `1.mp3`, `2.mp3` and so on.
private final class FakeAudioMetadataReader: AudioMetadataReader, @unchecked Sendable {
    typealias Read = @Sendable (_ file: Int) async -> Result<AudioMetadata, AudioMetadataReadError>

    private let read: Read
    private let lock = NSLock()
    private var state = State()

    private struct State {
        var requests: [String: [Bool]] = [:]
        var cancelledFiles: Set<Int> = []
        var concurrentReadCount = 0
        var maxConcurrentReadCount = 0
    }

    init(_ read: @escaping Read) {
        self.read = read
    }

    /// Whether each request asked for the cover, by name of the file
    /// requested.
    var requests: [String: [Bool]] {
        lock.withLock { state.requests }
    }

    /// Files whose read has returned after its cancellation.
    var cancelledFiles: Set<Int> {
        lock.withLock { state.cancelledFiles }
    }

    var maxConcurrentReadCount: Int {
        lock.withLock { state.maxConcurrentReadCount }
    }

    func read(_ request: AudioMetadataRequest) async -> Result<AudioMetadata, AudioMetadataReadError> {
        let filename = request.resource.sourceURL!.lastPathSegment!
        let file = Int(filename.prefix { $0 != "." }) ?? 0

        lock.withLock {
            state.requests[filename, default: []].append(request.includesCover)
            state.concurrentReadCount += 1
            state.maxConcurrentReadCount = max(state.maxConcurrentReadCount, state.concurrentReadCount)
        }

        let result = await read(file)

        lock.withLock {
            state.concurrentReadCount -= 1
            if Task.isCancelled {
                state.cancelledFiles.insert(file)
            }
        }
        return result
    }
}

private extension AudioParser {
    /// Creates a parser with the shared asset retriever.
    convenience init(
        metadataReader: AudioMetadataReader = DefaultAudioMetadataReader(),
        config: Configuration = .init()
    ) {
        self.init(assetRetriever: assetRetriever, metadataReader: metadataReader, config: config)
    }
}

private extension Format {
    static let folder = Format(specifications: .informalAudiobook)
}

private extension ListWarningLogger {
    var audioMetadataWarnings: [AudioMetadataWarning] {
        warnings.map { $0 as! AudioMetadataWarning }
    }
}

private extension Publication {
    /// Bytes served for the cover link, or nil without a cover.
    func coverBytes() async throws -> Data? {
        try await linkWithRel(.cover).flatMap { get($0) }?.read().get()
    }
}

private extension Link {
    /// This link with its bitrate and duration rounded, as they depend on the
    /// encoding of the fixtures.
    var rounded: Link {
        var link = self
        link.bitrate = bitrate?.rounded()
        link.duration = duration.map { ($0 * 10).rounded() / 10 }
        return link
    }
}
