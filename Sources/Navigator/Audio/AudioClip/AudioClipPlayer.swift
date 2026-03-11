//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
@preconcurrency import ReadiumShared

public enum AudioClipPlayerError: Error {
    /// Failed to load the audio clip.
    case failedToLoadClip
}

/// Plays individual audio clips from a ``Publication``, backed by `AVPlayer`.
///
/// The player renders a bounded region of an audio file and fires delegate
/// callbacks as playback progresses through segments.
@MainActor
public final class AudioClipPlayer: NSObject, Loggable {
    public weak var delegate: (any AudioClipPlayerDelegate)?

    public private(set) var status: AudioClipPlayerStatus = .idle {
        didSet {
            if oldValue != status {
                delegate?.audioClipPlayer(self, didChangeStatus: status)
            }
        }
    }

    public var time: TimeInterval {
        let seconds = avPlayer.currentTime().seconds
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
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        addPlayerObservers(on: avPlayer)
    }

    private let avPlayer = AVPlayer()
    private let segmentGapSeekThreshold: TimeInterval
    private lazy var resourceLoader = ResourceLoaderDelegate(player: self)

    private typealias Item = (clip: AudioClip, item: AVPlayerItem)

    /// The item currently loaded into `avPlayer`, if any.
    private var currentItem: Item?

    /// Index of the segment at the current position, if any.
    private var currentSegmentIndex: Int? {
        didSet {
            guard oldValue != currentSegmentIndex, let clip = currentItem?.clip else {
                return
            }

            if let index = currentSegmentIndex {
                delegate?.audioClipPlayer(self, willStartSegmentAt: index, in: clip)
            }
        }
    }

    /// Bridging intent across async gaps: `play()` sets this before kicking
    /// off an async seek. After the seek, we check it before calling
    /// `avPlayer.play()`, so a `pause()` or `stop()` issued during the seek is
    /// not overridden.
    private var playWhenReady = false

    /// Opaque tokens returned by `addBoundaryTimeObserver`.
    private var segmentObservers: [Any] = []

    /// Blocks registered via `addPeriodicTimeObserver`, keyed by UUID so they
    /// can be removed when the token is released.
    private var periodicObservers: [UUID: () -> Void] = [:]

    private var itemDidPlayToEndTimeObserver: NSObjectProtocol?
    private var playerTimeControlStatusObservation: NSKeyValueObservation?

    // MARK: - Playback

    /// Plays the given clip immediately, replacing any current playback.
    ///
    /// The player starts at `segments[startAt].start` (or `clip.start` when
    /// there are no segments), firing
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:willStartSegmentAt:in:)`` and
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didFinishSegmentAt:in:)`` at each
    /// segment boundary.
    ///
    /// - Parameter startAt: Index of the first segment to play. Defaults to 0.
    public func play(_ clip: AudioClip, startAt: Int = 0) {
        guard let item = makeItem(for: clip) else {
            replaceCurrentItem(nil)
            delegate?.audioClipPlayer(self, didFailPlaying: clip, withError: AudioClipPlayerError.failedToLoadClip)
            return
        }

        if let end = clip.end {
            // AVPlayer fires AVPlayerItemDidPlayToEndTime when this is reached.
            item.item.forwardPlaybackEndTime = makeTime(seconds: end)
        }

        replaceCurrentItem(item, segmentIndex: startAt)

        playWhenReady = true

        let startTime = clip.segments.getOrNil(startAt)?.start ?? clip.start
        avPlayer.seek(
            to: makeTime(seconds: startTime),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard finished, let self, self.playWhenReady else {
                    return
                }
                self.avPlayer.play()
            }
        }
    }

    /// Pauses playback.
    public func pause() {
        playWhenReady = false
        avPlayer.pause()
    }

    /// Resumes paused playback.
    public func resume() {
        guard currentItem != nil else { return }
        playWhenReady = true
        avPlayer.play()
    }

    /// Stops playback and clears state.
    public func stop() {
        replaceCurrentItem(nil)
    }

    // MARK: - Seeking and Skipping

    /// Seeks to the given position within the current clip, in seconds.
    ///
    /// If the current clip has segments, and `time` falls outside of all
    /// segments, the position will be moved to the start of the next closest
    /// segment.
    ///
    /// Any segment observers between the current position and `time` are
    /// skipped without firing.
    ///
    /// If `time` is past the clip's end, the player behaves as if the clip
    /// finished naturally and fires
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didFinishPlaying:)``.
    public func seek(to time: TimeInterval) {
        guard let currentItem else { return }

        // Snap to nearest segment if time falls in a gap.
        let target = snappedTime(time, in: currentItem.clip)

        // Treat a seek past the clip boundary as a natural end-of-clip.
        if let end = currentItem.clip.end, target >= end {
            didFinishPlaying()
            return
        }

        avPlayer.seek(
            to: makeTime(seconds: target),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    /// Skips to the next segment in the audio clip.
    ///
    /// - Returns: `true` if there is a next segment to skip to, `false`
    /// otherwise.
    public func skipToNextSegment() -> Bool {
        guard
            let segments = currentItem?.clip.segments,
            !segments.isEmpty
        else {
            return false
        }

        // Fix an issue when calling skipToNextSegment() consecutively quickly,
        // by using a small tolerance when finding the current segment to absorb
        // AVPlayer timescale quantization (e.g. seeking to 9.839 lands at
        // 9.838979..., which would otherwise re-match the same segment).
        let now = time + 0.002

        guard let nextIndex = segments.firstIndex(where: { $0.start > now }) else {
            return false
        }

        seekToSegment(nextIndex)
        return true
    }

    /// Skips to the previous segment in the audio clip.
    ///
    /// - Returns: `true` if there is a previous segment to skip to, `false`
    /// otherwise.
    public func skipToPreviousSegment() -> Bool {
        guard
            let segments = currentItem?.clip.segments,
            !segments.isEmpty
        else {
            return false
        }

        let now = time
        let currentIndex = segments.indices.last { segments[$0].start <= now } ?? 0
        guard currentIndex > 0 else {
            return false
        }

        seekToSegment(currentIndex - 1)
        return true
    }

    private func seekToSegment(_ index: Int) {
        guard let segment = currentItem?.clip.segments.getOrNil(index) else {
            return
        }
        currentSegmentIndex = index
        seek(to: segment.start)
    }

    /// Registers a block to be called at regular intervals while playing.
    ///
    /// - Parameters:
    ///   - interval: How often to fire the block, in seconds.
    ///   - block: Called on each tick; read `time` and `duration` from the
    ///     player directly (captured via `[weak self]` in the caller).
    /// - Returns: An opaque token that must be retained for as long as the
    ///   observation should remain active. Releasing the token cancels the
    ///   observer.
    public func addPeriodicTimeObserver(forInterval interval: TimeInterval, using block: @escaping () -> Void) -> Any {
        let avToken = avPlayer.addPeriodicTimeObserver(
            forInterval: makeTime(seconds: interval), queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.currentItem != nil else { return }
                block()
            }
        }

        let id = UUID()
        periodicObservers[id] = block

        return ObserverToken { [weak self, weak avPlayer] in
            avPlayer?.removeTimeObserver(avToken)
            self?.periodicObservers.removeValue(forKey: id)
        }
    }

    // MARK: - Private helpers

    /// Returns the effective seek target for `time` within `clip`, snapping
    /// to the start of the next segment when `time` falls in a gap.
    private func snappedTime(_ time: TimeInterval, in clip: AudioClip) -> TimeInterval {
        let segments = clip.segments
        guard !segments.isEmpty else {
            return max(time, clip.start)
        }

        // Before the first segment.
        if time < segments[0].start {
            return clip.start
        }

        for segment in segments {
            // In the gap between the previous segment and this one.
            if time < segment.start {
                return segment.start
            }
            // Within this segment.
            if let end = segment.end, time < end {
                return time
            }
        }

        // Past the last segment's end — treat as end-of-clip.
        return clip.end ?? time
    }

    private func replaceCurrentItem(_ item: Item?, segmentIndex: Int? = nil) {
        // Pause immediately so no audio bleeds through while we swap items.
        avPlayer.pause()
        playWhenReady = false

        removeSegmentObservers()

        currentItem = item
        currentSegmentIndex = segmentIndex
        avPlayer.replaceCurrentItem(with: item?.item)

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
                        let item = self.currentItem,
                        item.item == notification.object as? AVPlayerItem
                    else {
                        return
                    }

                    if let lastIndex = item.clip.segments.indices.last {
                        self.didFinishSegmentAt(lastIndex)
                    }

                    self.didFinishPlaying()
                }
            }

        playerTimeControlStatusObservation =
            player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.playerTimeControlStatusDidChange() }
            }
    }

    /// Called when the player reached the end of the clip.
    private func didFinishPlaying() {
        guard let item = currentItem else {
            return
        }

        replaceCurrentItem(nil)

        delegate?.audioClipPlayer(self, didFinishPlaying: item.clip)
    }

    /// Called when a segment finished naturally, without being interrupted by
    /// a seek.
    private func didFinishSegmentAt(_ index: Int) {
        guard
            let clip = currentItem?.clip,
            currentSegmentIndex == index
        else {
            return
        }

        delegate?.audioClipPlayer(self, didFinishSegmentAt: index, in: clip)
    }

    /// Called when the player changes its `timeControlStatus`.
    private func playerTimeControlStatusDidChange() {
        guard currentItem != nil else {
            status = .idle
            return
        }

        status = switch avPlayer.timeControlStatus {
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
                // the AVPlayerItemDidPlayToEndTime observer.
                continue
            }

            if
                let end = segment.end,
                nextStart - end >= segmentGapSeekThreshold
            {
                // The gap between this segment's end and the next segment's
                // start exceeds the threshold. Observe the end time and seek
                // over the gap.
                addSegmentObserver(at: end) { [weak self] in
                    guard let self else { return }

                    didFinishSegmentAt(i)
                    self.currentSegmentIndex = i + 1

                    self.avPlayer.seek(
                        to: self.makeTime(seconds: nextStart),
                        toleranceBefore: .zero,
                        toleranceAfter: .zero
                    )
                }

            } else {
                // Contiguous segments – observe at the next segment's start time.
                addSegmentObserver(at: nextStart) { [weak self] in
                    guard let self else { return }

                    didFinishSegmentAt(i)
                    self.currentSegmentIndex = i + 1
                }
            }
        }
    }

    private func addSegmentObserver(at time: TimeInterval, _ block: @MainActor @escaping () -> Void) {
        let timeValue = NSValue(time: makeTime(seconds: time))
        let token = avPlayer.addBoundaryTimeObserver(forTimes: [timeValue], queue: .main) {
            MainActor.assumeIsolated {
                block()
            }
        }

        segmentObservers.append(token)
    }

    private func removeSegmentObservers() {
        for observer in segmentObservers {
            avPlayer.removeTimeObserver(observer)
        }
        segmentObservers = []
    }

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

// MARK: - AudioClipPlayerDelegate

/// Receives playback events from an ``AudioClipPlayer``.
@MainActor public protocol AudioClipPlayerDelegate: AnyObject {
    /// Returns a `Resource` providing access to the audio data for `link`.
    ///
    /// The player calls this to open a publication resource by link.
    func audioClipPlayer(_ player: AudioClipPlayer, resourceFor link: Link) throws -> Resource

    /// Called when playback will begin playing the segment at the given `index`
    /// in the `clip`.
    ///
    /// This is called even if the segment is seeked through and does not start
    /// from the beginning.
    func audioClipPlayer(_ player: AudioClipPlayer, willStartSegmentAt index: Int, in clip: AudioClip)

    /// Called when playback reaches the natural end of the segment at the given
    /// `index` in the `clip`.
    ///
    /// If the segment is interrupted, it will not be called.
    func audioClipPlayer(_ player: AudioClipPlayer, didFinishSegmentAt index: Int, in clip: AudioClip)

    /// Called when the player finishes playing a clip, either because it
    /// reached the last segment's end or because `seek(to:)` was called past that point.
    func audioClipPlayer(_ player: AudioClipPlayer, didFinishPlaying clip: AudioClip)

    /// Called when the player's playback status changes.
    func audioClipPlayer(_ player: AudioClipPlayer, didChangeStatus status: AudioClipPlayerStatus)

    /// Called when an unrecoverable error occurs while playing `clip`.
    /// The player transitions to `idle` status (as if `stop()` was called).
    func audioClipPlayer(_ player: AudioClipPlayer, didFailPlaying clip: AudioClip, withError error: Error)
}

// MARK: - AudioClipPlayerStatus

/// The playback status of an ``AudioClipPlayer``.
///
/// Transitions typically follow: ``idle`` → ``loading`` → ``playing``.
/// Rebuffering mid-playback moves from ``playing`` back to ``loading``.
/// An explicit ``AudioClipPlayer/pause()`` call moves to ``paused`` from any
/// non-idle state.
public enum AudioClipPlayerStatus: Hashable, Sendable {
    /// No clip is loaded. The player is waiting for a ``AudioClipPlayer/play(_:)``
    /// call.
    case idle

    /// The player intends to play, but the clip is loading or waiting for
    /// enough data to start or resume.
    case loading

    /// The player is actively playing audio.
    case playing

    /// Playback is paused. The player will resume from the current position
    /// when ``AudioClipPlayer/resume()`` is called.
    case paused
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

    private weak var player: AudioClipPlayer?

    /// Tasks are keyed by `ObjectIdentifier(loadingRequest)` so they can be
    /// cancelled if AVFoundation withdraws the request via `didCancel`.
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// Links stored by normalized HREF so we can recover the media type.
    private var links: [AnyURL: Link] = [:]

    init(player: AudioClipPlayer) {
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
            throw DebugError("The AudioClipPlayer delegate is required to provide resources")
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
