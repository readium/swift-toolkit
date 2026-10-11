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
    @Suite("HREF of an asset URL") struct AssetURLHREF {
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
            #expect(ResourceAssetLoader.href(forAssetURL: URL(string: url)!)?.string == href)
        }

        @Test("is nil without the scheme prefix", arguments: [
            "relative/file.mp3",
            "file:///directory/file.mp3",
            "http:///domain.com/file.mp3",
        ])
        func withoutPrefix(url: String) {
            #expect(ResourceAssetLoader.href(forAssetURL: URL(string: url)!) == nil)
        }
    }

    @Suite("Serving a resource") struct Serving {
        @Test("loads the asset from the resource resolved with its normalized HREF", arguments: [true, false])
        func servesResolvedResource(hasEstimatedLength: Bool) async throws {
            // Given a loader resolving any HREF to a WAV resource, whose
            // length is known or not.
            let resource = StubResource(.serving(WAV.silence(duration: 1)), hasEstimatedLength: hasEstimatedLength)
            let resolvedHREFs = Mutex<[String]>([])
            let loader = ResourceAssetLoader { href in
                resolvedHREFs.withLock { $0.append(href.string) }
                return .init(href: href, resource: resource, mediaType: .wav)
            }

            // When loading an asset whose HREF has the extension of another
            // format, which the player refuses as a content type.
            let asset = try loader.makeAsset(for: AnyURL(string: "dir/../track.m4b")!)
            let duration = try await asset.loadDuration()

            // Then it is read from the resource, which is resolved once. So
            // the content type comes from the media type, not the extension.
            #expect(duration.seconds == 1)
            #expect(resolvedHREFs.withLock { $0 } == ["track.m4b"])
        }

        @Test("fails to load an asset which is not resolved to a resource")
        func unresolvedAsset() async throws {
            let resolvedHREFs = Mutex<Set<String>>([])
            let errors = Mutex<[ReportedError]>([])
            let loader = ResourceAssetLoader { href in
                resolvedHREFs.withLock { _ = $0.insert(href.string) }
                return nil
            }
            loader.onLoadingError = { href, error in
                errors.withLock { $0.append(ReportedError(href: href.string, error: error)) }
            }

            let asset = try loader.makeAsset(for: trackHREF)

            await #expect(throws: (any Error).self) { try await asset.loadDuration() }
            #expect(resolvedHREFs.withLock { $0 } == ["track.wav"])
            #expect(errors.withLock { $0 }.isEmpty)
        }

        /// The resources fail before any data request, so they never have an
        /// open one.
        @Test("keeps a resource until another entry is resolved", arguments: [
            (["a.wav", "a.wav"], ["a.wav"]),
            (["a.wav", "b.wav", "a.wav"], ["a.wav", "b.wav", "a.wav"]),
        ])
        func eviction(loadedHREFs: [String], expectedResolvedHREFs: [String]) async throws {
            let resolvedHREFs = Mutex<[String]>([])
            let loader = ResourceAssetLoader { href in
                resolvedHREFs.withLock { $0.append(href.string) }
                return .init(href: href, resource: FailureResource(error: .decoding("Unreadable")), mediaType: .wav)
            }

            for href in loadedHREFs {
                let asset = try loader.makeAsset(for: AnyURL(string: href)!)
                await #expect(throws: (any Error).self) { try await asset.loadDuration() }
            }

            #expect(resolvedHREFs.withLock { $0 } == expectedResolvedHREFs)
        }

        @Test("creates the asset with the given options")
        func assetOptions() throws {
            let loader = ResourceAssetLoader { _ in nil }

            let asset = try loader.makeAsset(for: trackHREF, options: [
                AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue,
            ])

            #expect(asset.referenceRestrictions == .forbidAll)
        }
    }

    @Suite("Failing to read a resource") struct LoadingError {
        @Test("is reported with the HREF of the entry", arguments: FailingStep.allCases)
        func reported(step: FailingStep) async throws {
            // Given a failing resource, resolved to an entry whose HREF
            // differs from the normalized one of the asset.
            let error = ReadError.access(.fileSystem(.fileNotFound(nil)))
            let errors = try await loadingErrors(
                of: step.resource(failingWith: error),
                entryHREF: AnyURL(string: "dir/../track.wav")!
            )

            // Then the error is reported with the HREF of the entry, for each
            // request which failed.
            #expect(!errors.isEmpty)
            #expect(errors.allSatisfy { $0 == ReportedError(href: "dir/../track.wav", error: error) })
        }

        @Test("is not reported for a cancellation", arguments: FailingStep.allCases)
        func cancellationNotReported(step: FailingStep) async throws {
            let errors = try await loadingErrors(
                of: step.resource(failingWith: .cancelled),
                entryHREF: trackHREF
            )

            #expect(errors.isEmpty)
        }
    }

    @Suite("Invalidating the loader") struct Invalidation {
        /// The stream in flight is the one of a data request when the length
        /// of the resource is known, and the one reading the whole resource
        /// for a content information request otherwise.
        @Test("returns once the in-flight streams have stopped, and fails their requests", arguments: [true, false])
        func stopsStreams(hasEstimatedLength: Bool) async throws {
            // Given an asset whose loading waits for a stream of its
            // resource.
            let resource = StubResource(.holding, hasEstimatedLength: hasEstimatedLength)
            let loader = ResourceAssetLoader(serving: resource)
            let asset = try loader.makeAsset(for: trackHREF)
            let loading = Task { try await asset.loadDuration() }
            await resource.wait(for: .started)

            // When invalidating the loader, while the stream only stops a
            // moment after its cancellation.
            resource.releaseCancelledStreams(after: 0.1)
            await loader.invalidate()

            // Then the stream has stopped, and the loading failed.
            #expect(resource.activeStreamCount == 0)
            await #expect(throws: (any Error).self) { try await loading.value }
        }

        @Test("returns once the streams of the requests abandoned by the player have stopped")
        func stopsAbandonedStreams() async throws {
            // Given an asset loaded from a resource too large to be delivered
            // before the player has what it needs. The player abandoned its
            // request running to the end of the resource, whose stream did
            // not stop yet.
            let resource = StubResource(.serving(WAV.silence(duration: 300)))
            let loader = ResourceAssetLoader(serving: resource)
            let asset = try loader.makeAsset(for: trackHREF)
            _ = try await asset.loadDuration()
            await resource.wait(for: .cancelled)

            // When invalidating the loader, while the stream only stops a
            // moment later.
            resource.releaseCancelledStreams(after: 0.1)
            await loader.invalidate()

            // Then every stream has stopped.
            #expect(resource.activeStreamCount == 0)
        }

        @Test("refuses the requests which follow, without resolving them")
        func refusesRequests() async throws {
            let resolvedHREFs = Mutex<[String]>([])
            let loader = ResourceAssetLoader { href in
                resolvedHREFs.withLock { $0.append(href.string) }
                return nil
            }
            await loader.invalidate()

            let asset = try loader.makeAsset(for: trackHREF)

            await #expect(throws: (any Error).self) { try await asset.loadDuration() }
            #expect(resolvedHREFs.withLock { $0 }.isEmpty)
        }
    }
}

// MARK: - Helpers

private let trackHREF = AnyURL(string: "track.wav")!

/// An error reported to `ResourceAssetLoader.onLoadingError`.
private struct ReportedError: Equatable {
    let href: String
    let error: ReadError
}

/// Returns the errors reported while failing to load an asset served from
/// `resource`, through an entry with the given HREF.
private func loadingErrors(of resource: Resource, entryHREF: AnyURL) async throws -> [ReportedError] {
    let errors = Mutex<[ReportedError]>([])
    let loader = ResourceAssetLoader { _ in
        .init(href: entryHREF, resource: resource, mediaType: .wav)
    }
    loader.onLoadingError = { href, error in
        errors.withLock { $0.append(ReportedError(href: href.string, error: error)) }
    }

    let asset = try loader.makeAsset(for: trackHREF)
    await #expect(throws: (any Error).self) { try await asset.loadDuration() }

    return errors.withLock { $0 }
}

/// The step at which reading a resource fails.
enum FailingStep: CaseIterable {
    /// Getting its length fails, for a content information request.
    case estimatedLength
    /// Its length is unknown, and reading it whole to get it fails.
    case read
    /// Its length is known, and streaming it fails, for a data request.
    case stream

    fileprivate func resource(failingWith error: ReadError) -> Resource {
        switch self {
        case .estimatedLength: FailureResource(error: error)
        case .read: StubResource(.failing(error), hasEstimatedLength: false)
        case .stream: StubResource(.failing(error))
        }
    }
}

private extension ResourceAssetLoader {
    /// Creates a loader serving `resource` as a WAV file, for any HREF.
    convenience init(serving resource: Resource) {
        self.init { href in
            .init(href: href, resource: resource, mediaType: .wav)
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

/// A `Resource` with a scripted behavior, reporting what happens to its
/// streams.
///
/// A stream whose task is cancelled stays active until
/// `releaseCancelledStreams(after:)` lets it end, as a stream which is slow
/// to notice its cancellation.
private final class StubResource: Resource {
    enum Behavior {
        /// The streams deliver the given data in chunks of `chunkSize`, one
        /// per millisecond.
        case serving(Data)
        /// The streams fail with the given error.
        case failing(ReadError)
        /// The streams deliver nothing until their task is cancelled.
        case holding
    }

    enum StreamEvent {
        case started
        /// The stream noticed the cancellation of its task.
        case cancelled
    }

    private static let chunkSize = 16384

    private let behavior: Behavior
    private let hasEstimatedLength: Bool

    private let activeStreams = Mutex(0)
    private let events: AsyncStream<StreamEvent>
    private let eventsContinuation: AsyncStream<StreamEvent>.Continuation

    /// Ends once the cancelled streams are released.
    private let release: Task<Void, Never>
    private let releaseContinuation: AsyncStream<Never>.Continuation

    /// - Parameter hasEstimatedLength: Whether the length is known without
    ///   reading the resource.
    init(_ behavior: Behavior, hasEstimatedLength: Bool = true) {
        self.behavior = behavior
        self.hasEstimatedLength = hasEstimatedLength
        (events, eventsContinuation) = AsyncStream.makeStream()

        let (releases, releaseContinuation) = AsyncStream<Never>.makeStream()
        self.releaseContinuation = releaseContinuation
        release = Task {
            for await _ in releases {}
        }
    }

    let sourceURL: AbsoluteURL? = nil

    /// Number of streams which did not end yet.
    var activeStreamCount: Int {
        activeStreams.withLock { $0 }
    }

    /// Waits until a stream reports `event`, or fails the test after ten
    /// seconds.
    func wait(for event: StreamEvent, sourceLocation: SourceLocation = #_sourceLocation) async {
        if await events.first(within: 10, where: { $0 == event }) == nil {
            Issue.record("Timed out waiting for a \(event) stream", sourceLocation: sourceLocation)
        }
    }

    /// Lets the cancelled streams end, `delay` seconds from now.
    func releaseCancelledStreams(after delay: TimeInterval) {
        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            releaseContinuation.finish()
        }
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
        activeStreams.withLock { $0 += 1 }
        defer { activeStreams.withLock { $0 -= 1 } }
        eventsContinuation.yield(.started)

        switch behavior {
        case let .serving(data):
            let start = Int(min(range?.lowerBound ?? 0, UInt64(data.count)))
            let end = Int(min(range?.upperBound ?? .max, UInt64(data.count)))
            for offset in stride(from: start, to: end, by: Self.chunkSize) {
                if offset > start {
                    try? await Task.sleep(nanoseconds: 1_000_000)
                    if Task.isCancelled {
                        return await cancelled()
                    }
                }
                consume(data[offset ..< min(offset + Self.chunkSize, end)])
            }
            return .success(())

        case let .failing(error):
            return .failure(error)

        case .holding:
            // The sleep ends when the task is cancelled.
            try? await Task.sleep(nanoseconds: 3_600_000_000_000)
            return await cancelled()
        }
    }

    /// Ends a cancelled stream once it is released.
    private func cancelled() async -> ReadResult<Void> {
        eventsContinuation.yield(.cancelled)
        await release.value
        return .failure(.cancelled)
    }
}
