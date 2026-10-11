//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
@testable import ReadiumShared
import Testing
import TestSupport

enum ResourceAssetLoaderTests {
    @Suite("HREF of an asset URL") struct AudioHREF {
        @Test("is the URL without the scheme prefix", arguments: [
            ("readium:relative/file.mp3", "relative/file.mp3"),
            ("readium:/absolute/file.mp3", "/absolute/file.mp3"),
            ("readiumfile:///directory/file.mp3", "file:///directory/file.mp3"),
            ("readiumhttp:///domain.com/file.mp3", "http:///domain.com/file.mp3"),
            ("readiumhttps:///domain.com/file.mp3", "https:///domain.com/file.mp3"),
            // Encoded characters
            ("readium:relative/a%20file.mp3", "relative/a%20file.mp3"),
            ("readiumhttps:///domain.com/a%20file.mp3", "https:///domain.com/a%20file.mp3"),
            // Normalization
            ("readium:dir/../file.mp3", "file.mp3"),
            ("readiumHTTPS://domain.com/./file.mp3", "https://domain.com/file.mp3"),
        ])
        func withPrefix(url: String, href: String) {
            #expect(URL(string: url)!.audioHREF?.string == href)
        }

        @Test("is nil without the scheme prefix", arguments: [
            "relative/file.mp3",
            "file:///directory/file.mp3",
            "http:///domain.com/file.mp3",
        ])
        func withoutPrefix(url: String) {
            #expect(URL(string: url)!.audioHREF == nil)
        }
    }

    @Suite("Serving a resource") struct Serving {
        @Test("loads the asset from the resource resolved with its normalized HREF", arguments: [true, false])
        func servesResolvedResource(hasEstimatedLength: Bool) async throws {
            // Given a loader resolving any HREF to a WAV resource, whose
            // length is known or not.
            let resource = StubResource(.serving(WAV.silence(duration: 1)), hasEstimatedLength: hasEstimatedLength)
            let resolvedHREFs = Recorder<String>()
            let loader = ResourceAssetLoader { href in
                resolvedHREFs.append(href.string)
                return .init(href: href, resource: resource, mediaType: .wav)
            }

            // When loading an asset, whose extension is the one of another
            // format.
            let asset = try loader.makeAsset(for: AnyURL(string: "dir/../track.m4b")!)
            let duration = try await asset.loadDuration()

            // Then it is read from the resource, which is resolved once and
            // served with its media type.
            #expect(duration.seconds == 1)
            #expect(resolvedHREFs.all == ["track.m4b"])
        }

        @Test("fails to load an asset which is not resolved to a resource")
        func unresolvedAsset() async throws {
            let resolvedHREFs = Recorder<String>()
            let loader = ResourceAssetLoader { href in
                resolvedHREFs.append(href.string)
                return nil
            }
            let errors = loader.recordLoadingErrors()

            let asset = try loader.makeAsset(for: trackHREF)

            await #expect(throws: (any Error).self) { try await asset.loadDuration() }
            #expect(Set(resolvedHREFs.all) == ["track.wav"])
            #expect(errors.all.isEmpty)
        }
    }

    @Suite("Failing to read a resource") struct LoadingError {
        @Test("is reported with the HREF of the entry", arguments: [true, false])
        func reported(hasEstimatedLength: Bool) async throws {
            // Given a failing resource, resolved to an entry whose HREF
            // differs from the normalized one of the asset. Its content
            // information fails when the length is unknown, its data
            // otherwise.
            let errors = try await loadingErrors(
                of: StubResource(.failing(.access(.fileSystem(.fileNotFound(nil)))), hasEstimatedLength: hasEstimatedLength),
                entryHREF: AnyURL(string: "dir/../track.wav")!,
                assetHREF: trackHREF
            )

            // Then the error is reported with the HREF of the entry.
            #expect(Set(errors) == [ReportedError(href: "dir/../track.wav", isFileNotFound: true)])
        }

        @Test("is not reported for a cancellation", arguments: [true, false])
        func cancellationNotReported(hasEstimatedLength: Bool) async throws {
            let errors = try await loadingErrors(
                of: StubResource(.failing(.cancelled), hasEstimatedLength: hasEstimatedLength),
                entryHREF: trackHREF,
                assetHREF: trackHREF
            )

            #expect(errors.isEmpty)
        }

        /// Returns the errors reported while failing to load an asset served
        /// from `resource`.
        private func loadingErrors(
            of resource: StubResource,
            entryHREF: AnyURL,
            assetHREF: AnyURL
        ) async throws -> [ReportedError] {
            let loader = ResourceAssetLoader { _ in
                .init(href: entryHREF, resource: resource, mediaType: .wav)
            }
            let errors = loader.recordLoadingErrors()

            let asset = try loader.makeAsset(for: assetHREF)
            await #expect(throws: (any Error).self) { try await asset.loadDuration() }

            return errors.all
        }
    }

    @Suite("Invalidating the loader") struct Invalidation {
        /// The held stream is the one of a data request when the length of
        /// the resource is known, and the one reading the whole resource for
        /// a content information request otherwise.
        @Test("returns once the in-flight streams have stopped, and no stream starts afterwards", arguments: [true, false])
        func stopsStreams(hasEstimatedLength: Bool) async throws {
            // Given an asset whose loading is held by a stream of its
            // resource.
            let resource = StubResource(.holding, hasEstimatedLength: hasEstimatedLength)
            let loader = ResourceAssetLoader(serving: resource)
            let asset = try loader.makeAsset(for: trackHREF)
            let loading = Task { try await asset.loadDuration() }
            await resource.waitForStream()

            // When invalidating the loader.
            await loader.invalidate()

            // Then the stream has ended, and the loading failed.
            #expect(resource.activeStreamCount == 0)
            await #expect(throws: (any Error).self) { try await loading.value }

            // And loading another asset fails without starting a stream.
            let streamCount = resource.streamCount
            let otherAsset = try loader.makeAsset(for: trackHREF)
            await #expect(throws: (any Error).self) { try await otherAsset.loadDuration() }
            #expect(resource.streamCount == streamCount)

            // And the loader can be invalidated again.
            await loader.invalidate()
        }

        @Test("returns once the streams of the requests abandoned by the player have stopped")
        func stopsAbandonedStreams() async throws {
            // Given an asset loaded from a resource too large to be delivered
            // before the player has what it needs, so that it abandons the
            // request running to the end of the resource.
            let resource = StubResource(.serving(WAV.silence(duration: 300)), hasEstimatedLength: true)
            let loader = ResourceAssetLoader(serving: resource)
            let asset = try loader.makeAsset(for: trackHREF)
            _ = try await asset.loadDuration()

            // When invalidating the loader.
            await loader.invalidate()

            // Then every stream has ended.
            #expect(resource.activeStreamCount == 0)
        }
    }
}

private let trackHREF = AnyURL(string: "track.wav")!

/// An error reported to `ResourceAssetLoader.onLoadingError`.
private struct ReportedError: Hashable {
    let href: String
    let isFileNotFound: Bool
}

/// Records the values received by a callback of the loader, on any thread.
private final class Recorder<Value: Sendable>: Sendable {
    private let values = Mutex<[Value]>([])

    var all: [Value] {
        values.withLock { $0 }
    }

    func append(_ value: Value) {
        values.withLock { $0.append(value) }
    }
}

private extension ResourceAssetLoader {
    /// Creates a loader serving `resource` as a WAV file, for any HREF.
    convenience init(serving resource: Resource) {
        self.init { href in
            .init(href: href, resource: resource, mediaType: .wav)
        }
    }

    /// Records the errors reported to `onLoadingError`.
    func recordLoadingErrors() -> Recorder<ReportedError> {
        let errors = Recorder<ReportedError>()
        onLoadingError = { href, error in
            errors.append(ReportedError(href: href.string, isFileNotFound: error.isFileNotFound))
        }
        return errors
    }
}

private extension ReadError {
    var isFileNotFound: Bool {
        if case .access(.fileSystem(.fileNotFound)) = self {
            true
        } else {
            false
        }
    }
}

private extension AVURLAsset {
    /// Loads the duration of the asset.
    ///
    /// When the loader leaves a request unanswered, the test fails after
    /// `timeout` seconds instead of hanging.
    func loadDuration(
        timeout: TimeInterval = 10,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> CMTime {
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            Issue.record("Timed out loading the asset", sourceLocation: sourceLocation)
            cancelLoading()
        }
        defer { timeoutTask.cancel() }

        return try await load(.duration)
    }
}

/// A `Resource` with a scripted behavior, counting its streams.
private final class StubResource: Resource {
    enum Behavior {
        /// The streams deliver the given data in chunks of 16 KB, one per
        /// millisecond.
        case serving(Data)
        /// The streams fail with the given error.
        case failing(ReadError)
        /// The streams deliver nothing until their task is cancelled.
        case holding
    }

    /// A cancelled stream only ends after this time, as a stream which is
    /// slow to notice its cancellation.
    private static let cancellationDelay: UInt64 = 200_000_000

    private let behavior: Behavior
    private let hasEstimatedLength: Bool

    private let counts = Mutex<(started: Int, active: Int)>((0, 0))
    private let streams: AsyncStream<Void>
    private let streamsContinuation: AsyncStream<Void>.Continuation

    /// - Parameter hasEstimatedLength: Whether the length is known without
    ///   reading the resource.
    init(_ behavior: Behavior, hasEstimatedLength: Bool) {
        self.behavior = behavior
        self.hasEstimatedLength = hasEstimatedLength
        (streams, streamsContinuation) = AsyncStream.makeStream()
    }

    let sourceURL: AbsoluteURL? = nil

    /// Number of streams started so far.
    var streamCount: Int {
        counts.withLock { $0.started }
    }

    /// Number of streams which did not end yet.
    var activeStreamCount: Int {
        counts.withLock { $0.active }
    }

    /// Waits until a stream started, or fails the test after `timeout`
    /// seconds.
    func waitForStream(
        timeout: TimeInterval = 10,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        // Finishing the stream ends the wait.
        let timeoutTask = Task { [streamsContinuation] in
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            streamsContinuation.finish()
        }
        defer { timeoutTask.cancel() }

        for await _ in streams {
            return
        }
        Issue.record("Timed out waiting for a stream", sourceLocation: sourceLocation)
    }

    func estimatedLength() async -> ReadResult<UInt64?> {
        guard hasEstimatedLength else {
            return .success(nil)
        }
        return switch behavior {
        case let .serving(data): .success(UInt64(data.count))
        case .failing, .holding: .success(1024)
        }
    }

    func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties())
    }

    func stream(range: Range<UInt64>?, consume: @escaping @Sendable (Data) -> Void) async -> ReadResult<Void> {
        counts.withLock { $0.started += 1; $0.active += 1 }
        defer { counts.withLock { $0.active -= 1 } }
        streamsContinuation.yield()

        switch behavior {
        case let .serving(data):
            let length = UInt64(data.count)
            let range = range.map { min($0.lowerBound, length) ..< min($0.upperBound, length) } ?? 0 ..< length
            for offset in stride(from: Int(range.lowerBound), to: Int(range.upperBound), by: 16384) {
                if offset > range.lowerBound {
                    try? await Task.sleep(nanoseconds: 1_000_000)
                    if Task.isCancelled {
                        return await cancelled()
                    }
                }
                consume(data[offset ..< min(offset + 16384, Int(range.upperBound))])
            }
            return .success(())

        case let .failing(error):
            return .failure(error)

        case .holding:
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
            return await cancelled()
        }
    }

    /// Ends a cancelled stream after `cancellationDelay`.
    private func cancelled() async -> ReadResult<Void> {
        // A sleep in the cancelled task would return at once.
        await Task.detached { try? await Task.sleep(nanoseconds: Self.cancellationDelay) }.value
        return .failure(.cancelled)
    }
}
