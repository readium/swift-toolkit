//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
@preconcurrency import ReadiumShared

public enum DefaultAudioClipPlayerError: Error {
    /// Failed to load the audio clip.
    case failedToLoadClip
}

/// An ``AudioClipPlayer`` implementation backed by `AVPlayer`.
@MainActor
public final class DefaultAudioClipPlayer: NSObject, AudioClipPlayer, Loggable {
    public weak var delegate: (any AudioClipPlayerDelegate)?

    public private(set) var status: AudioClipPlayerStatus = .idle {
        didSet {
            if oldValue != status {
                delegate?.audioClipPlayer(self, didChangeStatus: status)
            }
        }
    }

    public var time: TimeInterval {
        let seconds = player.currentTime().seconds
        if seconds.isFinite {
            return seconds
        } else if let item = currentItem {
            return item.clip.start
        } else {
            return 0
        }
    }

    public var duration: TimeInterval? {
        guard
            let duration = currentItem?.item.duration.seconds,
            duration.isFinite,
            duration > 0
        else {
            return nil
        }
        return duration
    }

    /// - Parameter segmentGapSeekThreshold: Minimum gap duration in seconds
    ///   between a segment's `end` and the next segment's `start` before the
    ///   player seeks over the gap rather than letting it play through.
    public init(segmentGapSeekThreshold: TimeInterval = 1) {
        self.segmentGapSeekThreshold = segmentGapSeekThreshold
        super.init()
        player.automaticallyWaitsToMinimizeStalling = false
        addPlayerObservers(on: player)
    }

    private let player = AVPlayer()
    private let segmentGapSeekThreshold: TimeInterval
    private lazy var resourceLoader = ResourceLoaderDelegate(player: self)

    private typealias Item = (clip: AudioClip, item: AVPlayerItem)

    /// The item currently loaded into `player`, if any.
    private var currentItem: Item?

    /// An asset pre-loaded by `prepare(_:)`, ready to be consumed by `play(_:)`
    /// if called for the same clip.
    private var preparedItem: Item?

    /// Bridging intent across async gaps: `play()` sets this before kicking
    /// off an async seek. After the seek, we check it before calling
    /// `player.play()`, so a `pause()` or `stop()` issued during the seek is
    /// not overridden.
    private var playWhenReady = false

    /// Opaque tokens returned by `addBoundaryTimeObserver`.
    private var segmentObservers: [Any] = []

    /// Blocks registered via `addPeriodicTimeObserver`, keyed by UUID so they
    /// can be removed when the token is released.
    private var periodicObservers: [UUID: () -> Void] = [:]

    private var itemDidPlayToEndTimeObserver: NSObjectProtocol?
    private var playerTimeControlStatusObservation: NSKeyValueObservation?

    // MARK: - AudioClipPlayer

    public func prepare(_ clip: AudioClip) {
        guard let item = makeItem(for: clip) else {
            preparedItem = nil
            log(.warning, "Failed to prepare audio asset: \(clip.link.href)")
            return
        }

        preparedItem = item
    }

    public func play(_ clip: AudioClip) {
        let item: Item? = preparedItem.takeIf { $0.clip == clip }
            ?? makeItem(for: clip)

        preparedItem = nil

        guard let item else {
            replaceCurrentItem(nil)
            delegate?.audioClipPlayer(self, didFailPlaying: clip, withError: DefaultAudioClipPlayerError.failedToLoadClip)
            return
        }

        if let end = clip.end {
            // AVPlayer fires AVPlayerItemDidPlayToEndTime when this is reached.
            item.item.forwardPlaybackEndTime = makeTime(seconds: end)
        }

        replaceCurrentItem(item)

        playWhenReady = true

        player.seek(
            to: makeTime(seconds: clip.start),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard finished, let self, self.playWhenReady else {
                    return
                }
                if !clip.segments.isEmpty {
                    self.delegate?.audioClipPlayer(self, willStartSegmentAt: 0, in: clip)
                }
                self.player.play()
            }
        }
    }

    public func pause() {
        playWhenReady = false
        player.pause()
    }

    public func resume() {
        guard currentItem != nil else { return }
        playWhenReady = true
        player.play()
    }

    public func stop() {
        replaceCurrentItem(nil)
        preparedItem = nil
    }

    public func seek(to time: TimeInterval) {
        guard let currentItem else { return }

        // Treat a seek past the clip boundary as a natural end-of-clip.
        if let end = currentItem.clip.end, time >= end {
            didPlayToEndTime()
            return
        }

        let time = max(time, currentItem.clip.start)
        player.seek(
            to: makeTime(seconds: time),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func replaceCurrentItem(_ item: Item?) {
        // Pause immediately so no audio bleeds through while we swap items.
        player.pause()
        playWhenReady = false

        removeSegmentObservers()

        currentItem = item
        player.replaceCurrentItem(with: item?.item)

        if let item = item {
            status = .paused
            addSegmentObservers(for: item.clip)
        } else {
            status = .idle
        }

        for block in periodicObservers.values {
            block()
        }
    }

    // MARK: - KVO / Notifications

    private func addPlayerObservers(on player: AVPlayer) {
        itemDidPlayToEndTimeObserver =
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard
                        let self = self,
                        let currentItem = self.currentItem,
                        currentItem.item == notification.object as? AVPlayerItem
                    else {
                        return
                    }
                    self.didPlayToEndTime()
                }
            }

        playerTimeControlStatusObservation =
            player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.playerTimeControlStatusDidChange() }
            }
    }

    // MARK: - AudioClipPlayer

    public func addPeriodicTimeObserver(forInterval interval: TimeInterval, using block: @escaping () -> Void) -> Any {
        let avToken = player.addPeriodicTimeObserver(
            forInterval: makeTime(seconds: interval), queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.currentItem != nil else { return }
                block()
            }
        }

        let id = UUID()
        periodicObservers[id] = block

        return ObserverToken { [weak self, weak player] in
            player?.removeTimeObserver(avToken)
            self?.periodicObservers.removeValue(forKey: id)
        }
    }

    /// Called when the player notifies `AVPlayerItemDidPlayToEndTime`.
    private func didPlayToEndTime() {
        let finishedItem = currentItem
        replaceCurrentItem(nil)

        if let item = finishedItem {
            if let lastIndex = item.clip.segments.indices.last {
                delegate?.audioClipPlayer(self, didFinishSegmentAt: lastIndex, in: item.clip)
            }
            delegate?.audioClipPlayer(self, didFinishPlaying: item.clip)
        }
    }

    /// Called when the player changes its `timeControlStatus`.
    private func playerTimeControlStatusDidChange() {
        guard currentItem != nil else {
            status = .idle
            return
        }

        status = switch player.timeControlStatus {
        case .paused: .paused
        case .waitingToPlayAtSpecifiedRate: .loading
        case .playing: .playing
        @unknown default: .paused
        }
    }

    private func addSegmentObservers(for clip: AudioClip) {
        for (i, segment) in clip.segments.enumerated() {
            guard let nextStart = clip.segments.getOrNil(i + 1)?.start else {
                // The last segment's didFinishSegmentAt is fired in
                // didPlayToEndTime.
                continue
            }

            if
                let end = segment.end,
                nextStart - end >= segmentGapSeekThreshold
            {
                // The gap between this segment's end and the next segment's
                // start exceeds the threshold. Observe the end time: fire
                // didFinish, seek over the gap, then fire willStart after the
                // seek lands.
                addSegmentObserver(at: end) { [weak self] in
                    guard let self, let item = self.currentItem else { return }

                    self.delegate?.audioClipPlayer(self, didFinishSegmentAt: i, in: item.clip)

                    let capturedItem = item
                    self.player.seek(
                        to: self.makeTime(seconds: nextStart),
                        toleranceBefore: .zero,
                        toleranceAfter: .zero
                    ) { [weak self] finished in
                        guard finished else { return }

                        Task { @MainActor [weak self] in
                            guard let self, self.currentItem?.item == capturedItem.item else { return }
                            self.delegate?.audioClipPlayer(self, willStartSegmentAt: i + 1, in: item.clip)
                        }
                    }
                }

            } else {
                // Contiguous segments – observe at the next segment's start time.
                addSegmentObserver(at: nextStart) { [weak self] in
                    guard let self, let item = self.currentItem else { return }
                    self.delegate?.audioClipPlayer(self, didFinishSegmentAt: i, in: item.clip)
                    self.delegate?.audioClipPlayer(self, willStartSegmentAt: i + 1, in: item.clip)
                }
            }
        }
    }

    private func addSegmentObserver(at time: TimeInterval, _ block: @MainActor @escaping () -> Void) {
        let timeValue = NSValue(time: makeTime(seconds: time))
        let token = player.addBoundaryTimeObserver(forTimes: [timeValue], queue: .main) {
            MainActor.assumeIsolated {
                block()
            }
        }

        segmentObservers.append(token)
    }

    private func removeSegmentObservers() {
        for observer in segmentObservers {
            player.removeTimeObserver(observer)
        }
        segmentObservers = []
    }

    // MARK: - Helpers

    private func makeItem(for clip: AudioClip) -> Item? {
        resourceLoader.makeAsset(for: clip.link)
            .map { (clip, AVPlayerItem(asset: $0)) }
    }

    private func makeTime(seconds: TimeInterval) -> CMTime {
        // The standard for audio timescales is 44100 Hz (CD quality) or
        // 48000 Hz. 44100 is the safer cross-format default.
        CMTime(seconds: seconds, preferredTimescale: 44100)
    }

    private final class ObserverToken {
        private let cancel: () -> Void
        init(cancel: @escaping () -> Void) {
            self.cancel = cancel
        }

        deinit { cancel() }
    }
}

// MARK: - ResourceLoaderDelegate

// Bridges AVFoundation resource-loading requests to Readium `Resource`
// objects.

/// Publication resources are not file-system URLs, so `AVPlayer` cannot open
/// them directly. Instead, each `AVURLAsset` is created with a custom
/// `readium`-prefixed scheme (e.g. `readiumhttps://…` or `readium:path`).
/// AVFoundation intercepts requests for that scheme and routes them to
/// `ResourceLoaderDelegate`, which fetches the bytes from the `Resource`
/// returned by the delegate and streams them back to AVFoundation chunk by
/// chunk.
///
/// AVFoundation calls `shouldWaitForLoadingOfRequestedResource` on a private
/// serial queue (`queue`) for every byte-range or content-info request it
/// needs. Each request is fulfilled asynchronously via a Swift `Task` that:
///   1. Hops to the main actor to ask the `AudioClipPlayerDelegate` for a
///     `Resource`.
///   2. Optionally fills a `contentInformationRequest` (MIME type + length).
///   3. Streams the requested byte range back through
///     `dataRequest.respond(with:)`.
///
/// `@unchecked Sendable` because `tasks` is mutable shared state, but every
/// read and write is serialized through `queue`, which Swift's type system
/// cannot verify. Using an actor instead would conflict with AVFoundation's
/// requirement that the delegate be called on a caller-supplied dispatch queue.
private final class ResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    private let schemePrefix = "readium"
    private let queue = DispatchQueue(label: "org.readium.swift-toolkit.audio-navigator.ResourceLoaderDelegate")

    private weak var player: DefaultAudioClipPlayer?

    /// Tasks are keyed by `ObjectIdentifier(loadingRequest)` so they can be
    /// cancelled if AVFoundation withdraws the request via `didCancel`.
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// Links stored by normalized HREF so we can recover the media type.
    private var links: [AnyURL: Link] = [:]

    init(player: DefaultAudioClipPlayer) {
        self.player = player
    }

    /// Creates a new `AVURLAsset` to serve the given `link` with this loader.
    func makeAsset(for link: Link) -> AVURLAsset? {
        let href = link.url().normalized
        guard let url = hrefToURL(href) else {
            return nil
        }
        links[href] = link
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(self, queue: queue)
        return asset
    }

    // MARK: - URL Helpers

    /// Rewrites a publication `href` into a URL with the `readium`-prefixed
    /// scheme that triggers this resource loader.
    ///
    /// If we don't use a custom scheme, the `AVAssetResourceLoaderDelegate`
    /// methods will never be called.
    ///
    /// - Absolute URLs: scheme is prefixed (e.g. `https` → `readiumhttps`).
    /// - Relative URLs: assembled as `readium:<relative-string>`.
    func hrefToURL(_ href: AnyURL) -> URL? {
        guard var components = URLComponents(url: href.url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        components.scheme = schemePrefix + (components.scheme ?? "")
        return components.url
    }

    /// Strips the `readium`-prefix scheme added by `hrefToURL()`, returning
    /// the original publication HREF. Returns `nil` for URLs that were not
    /// created by this loader.
    func urlToHREF(_ url: URL) -> AnyURL? {
        guard
            let url = url.anyURL.absoluteURL,
            url.scheme.rawValue.hasPrefix(schemePrefix)
        else {
            return nil
        }
        return AnyURL(string: url.string.removingPrefix(schemePrefix).removingPrefix(":"))?.normalized
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        guard
            let url = loadingRequest.request.url,
            let href = urlToHREF(url),
            let link = links[href]
        else {
            return false
        }

        let key = ObjectIdentifier(loadingRequest)
        tasks[key] = Task { [weak self] in
            guard let self else { return }
            await self.fulfill(loadingRequest, link: link)
            self.queue.async { self.tasks.removeValue(forKey: key) }
        }
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        tasks.removeValue(forKey: ObjectIdentifier(loadingRequest))?.cancel()
    }

    // MARK: - Request Fulfillment

    /// Fetches the resource for `link` and streams it into `loadingRequest`.
    private func fulfill(_ loadingRequest: AVAssetResourceLoadingRequest, link: Link) async {
        do {
            let resource = try await fetchResource(for: link)

            // Fill content information when requested. On failure abort
            // immediately; on success fall through — AVFoundation may combine
            // both sub-requests.
            if let infoRequest = loadingRequest.contentInformationRequest {
                try await fillInfo(infoRequest, link: link, resource: resource)
            }

            if let dataRequest = loadingRequest.dataRequest {
                try await resource.stream(
                    range: byteRange(for: dataRequest),
                    consume: { dataRequest.respond(with: $0) }
                ).get()
            }
            loadingRequest.finishLoading()
        } catch {
            loadingRequest.finishLoading(with: error)
        }
    }

    /// Asks the player delegate for the `Resource` backing `link`.
    @MainActor private func fetchResource(for link: Link) async throws -> Resource {
        guard let player, let delegate = player.delegate else {
            throw DebugError("The DefaultAudioClipPlayer delegate is required to provide resources")
        }
        return try delegate.audioClipPlayer(player, resourceFor: link)
    }

    /// Populates `infoRequest` with the media type and byte length of
    /// `resource`.
    ///
    /// If the resource length is unknown (no `Content-Length` header, etc.),
    /// byte-range access is disabled so AVFoundation treats the resource as a
    /// non-seekable stream rather than failing the request entirely.
    private func fillInfo(
        _ infoRequest: AVAssetResourceLoadingContentInformationRequest,
        link: Link,
        resource: Resource
    ) async throws {
        infoRequest.contentType = link.mediaType?.uti

        switch await resource.estimatedLength() {
        case let .success(length?):
            infoRequest.isByteRangeAccessSupported = true
            infoRequest.contentLength = Int64(length)
        default:
            infoRequest.isByteRangeAccessSupported = false
        }
    }

    /// Returns the byte range that AVFoundation wants for `dataRequest`.
    /// Returns `nil` when the request covers the entire resource from offset 0.
    private func byteRange(for dataRequest: AVAssetResourceLoadingDataRequest) -> Range<UInt64>? {
        let offset = UInt64(dataRequest.currentOffset)
        if dataRequest.requestsAllDataToEndOfResource {
            // nil means "from currentOffset to EOF"; skip the range entirely when starting at 0.
            return offset > 0 ? offset ..< UInt64.max : nil
        } else {
            return offset ..< offset + UInt64(dataRequest.requestedLength)
        }
    }
}
