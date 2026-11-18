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

    @Suite("Creating an asset") struct AssetCreation {
        @Test("serves it with the loader, at the normalized HREF", arguments: [
            "dir/../track.wav",
            "file:///dir/track.wav",
            "https://domain.com/track.wav",
        ])
        func servedByTheLoader(href: String) throws {
            let loader = ResourceAssetLoader(serving: nil)
            let url = AnyURL(string: href)!

            let asset = try loader.makeAsset(for: url)

            #expect(ResourceAssetLoader.href(forAssetURL: asset.url) == url.normalized)
            #expect(asset.resourceLoader.delegate === loader)
            #expect(asset.resourceLoader.delegateQueue === loader.queue)
        }

        @Test("applies the given options")
        func options() throws {
            let loader = ResourceAssetLoader(serving: nil)

            let asset = try loader.makeAsset(for: trackHREF, options: [
                AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue,
            ])

            #expect(asset.referenceRestrictions == .forbidAll)
        }
    }

    @Suite("Serving a resource") struct Serving {
        @Test("answers from the resource resolved once with the normalized HREF", arguments: [true, false])
        func servesResolvedResource(hasEstimatedLength: Bool) async throws {
            // Given a loader serving a WAV resource, whose length is known or
            // not.
            let resolvedHREFs = ResolvedHREFs()
            let loader = ResourceAssetLoader(
                serving: StubResource(.serving(bytes), hasEstimatedLength: hasEstimatedLength),
                resolvedHREFs: resolvedHREFs
            )

            // When the player asks for the content information, then the data,
            // of an asset whose HREF has the extension of another format.
            let info = try await loader.answer(.contentInformation, href: "dir/../track.m4b")
            let data = try await loader.answer(.wholeResource, href: "dir/../track.m4b")

            // Then the content type comes from the media type, not the
            // extension, and the requests are answered from the resource.
            #expect(info.contentInformation == FakeLoadingRequest.ContentInformation(contentType: MediaType.wav.uti, contentLength: Int64(bytes.count)))
            #expect(info.error == nil)
            #expect(data.data == bytes)
            #expect(data.error == nil)
            #expect(resolvedHREFs.all == ["track.m4b"])
        }

        struct ServedRange: Sendable, CustomTestStringConvertible {
            let kind: AssetLoadingRequestKind
            let expected: Range<Int>

            var testDescription: String {
                "\(kind) serves \(expected)"
            }
        }

        /// The length is ignored only for the whole resource, requested to
        /// its end from its start.
        @Test("serves the requested range of bytes", arguments: [
            ServedRange(kind: .data(offset: 0, length: 2, toEnd: true), expected: 0 ..< 100),
            ServedRange(kind: .data(offset: 0, length: 5, toEnd: false), expected: 0 ..< 5),
            ServedRange(kind: .data(offset: 10, length: 5, toEnd: false), expected: 10 ..< 15),
            ServedRange(kind: .data(offset: 10, length: 90, toEnd: true), expected: 10 ..< 100),
        ])
        func servesRange(_ example: ServedRange) async throws {
            let loader = ResourceAssetLoader(serving: StubResource(.serving(bytes)))

            let request = try await loader.answer(example.kind)

            #expect(request.data == bytes[example.expected])
            #expect(request.error == nil)
        }

        @Test("refuses an asset which is not resolved to a resource")
        func unresolvedAsset() {
            let resolvedHREFs = ResolvedHREFs()
            let errors = Mutex<[ReportedError]>([])
            let loader = ResourceAssetLoader(serving: nil, resolvedHREFs: resolvedHREFs)
            loader.onLoadingError = { href, error in
                errors.withLock { $0.append(ReportedError(href: href.string, error: error)) }
            }

            #expect(!loader.send(FakeLoadingRequest(.contentInformation)))
            #expect(resolvedHREFs.all == ["track.wav"])
            #expect(errors.withLock { $0 }.isEmpty)
        }

        struct Eviction: Sendable, CustomTestStringConvertible {
            let loadedHREFs: [String]
            let expectedResolvedHREFs: [String]

            var testDescription: String {
                loadedHREFs.joined(separator: ", ")
            }
        }

        @Test("keeps a resource until another entry is resolved", arguments: [
            Eviction(loadedHREFs: ["a.wav", "a.wav"], expectedResolvedHREFs: ["a.wav"]),
            Eviction(loadedHREFs: ["a.wav", "b.wav", "a.wav"], expectedResolvedHREFs: ["a.wav", "b.wav", "a.wav"]),
        ])
        func eviction(_ example: Eviction) {
            let resolvedHREFs = ResolvedHREFs()
            let loader = ResourceAssetLoader(serving: StubResource(.serving(bytes)), resolvedHREFs: resolvedHREFs)

            for href in example.loadedHREFs {
                #expect(loader.send(FakeLoadingRequest(.contentInformation, href: href)))
            }

            #expect(resolvedHREFs.all == example.expectedResolvedHREFs)
        }

        @Test("keeps the resource of an open data request when another entry is resolved, until it is abandoned", arguments: [false, true])
        func evictionWithDataRequest(isAbandoned: Bool) async {
            let resource = StubResource(.holding)
            let resolvedHREFs = ResolvedHREFs()
            let loader = ResourceAssetLoader(serving: resource, resolvedHREFs: resolvedHREFs)

            let dataRequest = FakeLoadingRequest(.wholeResource, href: "a.wav")
            #expect(loader.send(dataRequest))
            if isAbandoned {
                loader.abandon(dataRequest)
            }
            #expect(loader.send(FakeLoadingRequest(.contentInformation, href: "b.wav")))
            #expect(loader.send(FakeLoadingRequest(.contentInformation, href: "a.wav")))

            #expect(resolvedHREFs.all == (isAbandoned ? ["a.wav", "b.wav", "a.wav"] : ["a.wav", "b.wav"]))

            resource.releaseCancelledStreams(after: 0)
            await loader.invalidate()
        }

        @Test("loads an asset with AVFoundation", .requiresAVFoundationLoading)
        func loadsAsset() async throws {
            let loader = ResourceAssetLoader(serving: StubResource(.serving(WAV.silence(duration: 1))))

            // The extension of another format, which the player refuses as a
            // content type.
            let asset = try loader.makeAsset(for: AnyURL(string: "dir/../track.m4b")!)

            #expect(try await asset.loadDuration().seconds == 1)
        }
    }

    @Suite("Failing to read a resource") struct LoadingError {
        @Test("is reported with the HREF of the entry, and fails the request", arguments: FailingStep.allCases)
        func reported(step: FailingStep) async throws {
            // Given a failing resource, resolved to an entry whose HREF
            // differs from the normalized one of the asset.
            let error = ReadError.access(.fileSystem(.fileNotFound(nil)))
            let (errors, failedRequest) = try await loadingErrors(
                of: step.resource(failingWith: error),
                entryHREF: AnyURL(string: "dir/../track.wav")!
            )

            #expect(errors == [ReportedError(href: "dir/../track.wav", error: error)])
            #expect(failedRequest.error as? ReadError == error)
        }

        @Test("is not reported for a cancellation, but fails the request", arguments: FailingStep.allCases)
        func cancellationNotReported(step: FailingStep) async throws {
            let (errors, failedRequest) = try await loadingErrors(
                of: step.resource(failingWith: .cancelled),
                entryHREF: trackHREF
            )

            #expect(errors.isEmpty)
            #expect(failedRequest.error as? ReadError == .cancelled)
        }
    }

    @Suite("Invalidating the loader") struct Invalidation {
        /// The stream of a content information request reads the whole
        /// resource, as its length is unknown.
        @Test("returns once the in-flight streams have stopped, and fails their requests", arguments: [
            AssetLoadingRequestKind.contentInformation,
            .wholeResource,
        ])
        func stopsStreams(kind: AssetLoadingRequestKind) async {
            let resource = StubResource(.holding, hasEstimatedLength: false)
            let loader = ResourceAssetLoader(serving: resource)
            let request = FakeLoadingRequest(kind)
            #expect(loader.send(request))
            #expect(await resource.wait(for: .started))

            // When invalidating the loader, while the stream only stops a
            // moment after its cancellation.
            resource.releaseCancelledStreams(after: 0.1)
            await loader.invalidate()

            #expect(resource.activeStreamCount == 0)
            #expect(request.error as? ReadError == .cancelled)
        }

        @Test("returns once the streams of the requests abandoned by the player have stopped, without finishing them")
        func stopsAbandonedStreams() async {
            // Given a data request abandoned by the player, whose stream did
            // not stop yet.
            let resource = StubResource(.holding)
            let loader = ResourceAssetLoader(serving: resource)
            let request = FakeLoadingRequest(.wholeResource)
            #expect(loader.send(request))
            #expect(await resource.wait(for: .started))
            loader.abandon(request)
            #expect(await resource.wait(for: .cancelled))

            // When invalidating the loader, while the stream only stops a
            // moment later.
            resource.releaseCancelledStreams(after: 0.1)
            await loader.invalidate()

            #expect(resource.activeStreamCount == 0)
            #expect(!request.isFinished)
        }

        @Test("refuses the requests which follow, without resolving them")
        func refusesRequests() async {
            let resolvedHREFs = ResolvedHREFs()
            let loader = ResourceAssetLoader(serving: StubResource(.serving(bytes)), resolvedHREFs: resolvedHREFs)
            await loader.invalidate()

            #expect(!loader.send(FakeLoadingRequest(.contentInformation)))
            #expect(resolvedHREFs.all.isEmpty)
        }
    }
}

// MARK: - Helpers

private let trackHREF = AnyURL(string: "track.wav")!

/// Bytes whose value is their offset, to check the served ranges.
private let bytes = Data((0 ..< 100).map { UInt8($0) })

/// An error reported to `ResourceAssetLoader.onLoadingError`.
private struct ReportedError: Equatable {
    let href: String
    let error: ReadError
}

/// Returns the errors reported while the player loads `resource` through an
/// entry with the given HREF, with the request which failed.
///
/// The player asks for the content information, then for the data when it
/// succeeded.
private func loadingErrors(of resource: Resource, entryHREF: AnyURL) async throws -> (errors: [ReportedError], failedRequest: FakeLoadingRequest) {
    let errors = Mutex<[ReportedError]>([])
    let loader = ResourceAssetLoader { _ in
        .init(href: entryHREF, resource: resource, mediaType: .wav)
    }
    loader.onLoadingError = { href, error in
        errors.withLock { $0.append(ReportedError(href: href.string, error: error)) }
    }

    var request = try await loader.answer(.contentInformation)
    if request.error == nil {
        request = try await loader.answer(.wholeResource)
    }

    return (errors.withLock { $0 }, request)
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

private extension AssetLoadingRequestKind {
    /// Every byte of the resource.
    static let wholeResource = AssetLoadingRequestKind.data(offset: 0, length: 2, toEnd: true)
}

/// HREFs resolved by a loader, in order.
private final class ResolvedHREFs: Sendable {
    private let hrefs = Mutex<[String]>([])

    var all: [String] {
        hrefs.withLock { $0 }
    }

    func append(_ href: AnyURL) {
        hrefs.withLock { $0.append(href.string) }
    }
}

/// A loading request of a fake player, recording how the loader answers it.
private final class FakeLoadingRequest: AssetLoadingRequest {
    struct ContentInformation: Equatable {
        let contentType: String?
        let contentLength: Int64
    }

    let url: URL?
    let kind: AssetLoadingRequestKind?

    private struct State {
        var contentInformation: ContentInformation?
        var data = Data()
        var isFinished = false
        var error: (any Error)?
        var isCancelled = false
    }

    private let state = Mutex(State())
    private let finishes: AsyncStream<Void>
    private let finishesContinuation: AsyncStream<Void>.Continuation

    init(_ kind: AssetLoadingRequestKind, href: String = "track.wav") {
        url = URL(string: "readium:\(href)")
        self.kind = kind
        (finishes, finishesContinuation) = AsyncStream.makeStream()
    }

    var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    var contentInformation: ContentInformation? {
        state.withLock { $0.contentInformation }
    }

    var data: Data {
        state.withLock { $0.data }
    }

    var error: (any Error)? {
        state.withLock { $0.error }
    }

    var isFinished: Bool {
        state.withLock { $0.isFinished }
    }

    var isCancelled: Bool {
        state.withLock { $0.isCancelled }
    }

    func setContentInformation(contentType: String?, contentLength: Int64) {
        state.withLock { $0.contentInformation = ContentInformation(contentType: contentType, contentLength: contentLength) }
    }

    func respond(with data: Data) {
        state.withLock { $0.data.append(data) }
    }

    func finishLoading(with error: (any Error)?) {
        state.withLock {
            $0.isFinished = true
            $0.error = error
        }
        finishesContinuation.yield()
    }

    /// Abandons the request, as the player does before telling the loader.
    func cancel() {
        state.withLock { $0.isCancelled = true }
    }

    /// Waits until the loader finishes the request. Returns false when it
    /// did not after `TimeInterval.testTimeout`.
    func waitUntilFinished() async -> Bool {
        await finishes.first(within: .testTimeout) != nil
    }
}

private extension ResourceAssetLoader {
    /// Creates a loader serving `resource` as a WAV file for any HREF, or
    /// no resource when `nil`, recording the HREFs it resolves.
    convenience init(serving resource: Resource?, resolvedHREFs: ResolvedHREFs? = nil) {
        self.init { href in
            resolvedHREFs?.append(href)
            return resource.map { .init(href: href, resource: $0, mediaType: .wav) }
        }
    }

    // `send` and `abandon` block the calling thread on the queue only
    // briefly, as the loader serves a request in a task of its own.

    /// Sends `request` as the player does. Returns whether the loader serves
    /// it.
    func send(_ request: FakeLoadingRequest) -> Bool {
        queue.sync { load(request) }
    }

    /// Abandons `request` as the player does.
    func abandon(_ request: FakeLoadingRequest) {
        request.cancel()
        queue.sync { cancel(request) }
    }

    /// Sends a request of the given kind for the asset at `href`, and returns
    /// it once the loader finished it.
    func answer(
        _ kind: AssetLoadingRequestKind,
        href: String = "track.wav",
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> FakeLoadingRequest {
        let request = FakeLoadingRequest(kind, href: href)
        try #require(send(request), sourceLocation: sourceLocation)
        try #require(await request.waitUntilFinished(), sourceLocation: sourceLocation)
        return request
    }
}

private extension Trait where Self == ConditionTrait {
    /// Skips a test loading an asset with AVFoundation when running on the
    /// CI, as AVFoundation times out its requests during the stalls of the
    /// runners.
    static var requiresAVFoundationLoading: Self {
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "AVFoundation times out its requests during the stalls of the CI runners"
        )
    }
}

private extension AVURLAsset {
    /// Loads the duration of the asset.
    ///
    /// When the loader leaves a request unanswered, the test fails after
    /// `timeout` seconds instead of hanging.
    func loadDuration(
        timeout: TimeInterval = .testTimeout,
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
