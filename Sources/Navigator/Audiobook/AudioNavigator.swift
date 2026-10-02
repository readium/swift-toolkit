//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import ReadiumShared

/// Status of a played media resource.
public enum MediaPlaybackState: Sendable {
    /// The playback is paused, and `play()` resumes it.
    ///
    /// This includes a playback held at the end of a resource by
    /// `AudioNavigatorDelegate.navigator(_:shouldPlayNextResource:)`, in
    /// which case `play()` moves on to the next resource.
    case paused

    /// The playback is requested but the player is not playing yet, as it is
    /// waiting for the audio session, buffering media data or completing a
    /// seek.
    case loading

    /// The player is playing.
    case playing

    /// The playback reached the end of the publication, by playing or seeking
    /// up to it.
    ///
    /// The player is paused at the end of the last resource. `play()` restarts
    /// from the beginning of the publication.
    case ended

    /// Whether the player is playing, or will as soon as it is ready.
    ///
    /// Use it for example to choose between a play and a pause button.
    public var playsWhenReady: Bool {
        switch self {
        case .loading, .playing:
            true
        case .paused, .ended:
            false
        }
    }
}

/// Holds metadata about a played media resource.
public struct MediaPlaybackInfo: Sendable {
    /// Index of the current resource in the `readingOrder`.
    public let resourceIndex: Int

    /// Indicates whether the resource is currently playing or not.
    public let state: MediaPlaybackState

    /// Current playback position in the resource, in seconds.
    public let time: Double

    /// Duration in seconds of the resource, if known.
    public let duration: Double?

    /// Progress in the resource, from 0 to 1.
    public var progress: Double {
        guard let duration = duration else {
            return 0
        }
        return time / duration
    }

    public init(
        resourceIndex: Int = 0,
        state: MediaPlaybackState = .loading,
        time: Double = 0,
        duration: Double? = nil
    ) {
        self.resourceIndex = resourceIndex
        self.state = state
        self.time = time
        self.duration = duration
    }
}

@MainActor public protocol AudioNavigatorDelegate: NavigatorDelegate {
    /// Called when the playback updates.
    func navigator(_ navigator: AudioNavigator, playbackDidChange info: MediaPlaybackInfo)

    /// Called when the navigator reached the end of the current resource, by
    /// playing or seeking up to it.
    /// Returns whether the next resource should be played. Default is true.
    ///
    /// This is not called after the last resource. The playback is reported
    /// as `.ended` instead.
    func navigator(_ navigator: AudioNavigator, shouldPlayNextResource info: MediaPlaybackInfo) -> Bool

    /// Called when the ranges of buffered media data change.
    /// Warning: They may be discontinuous.
    func navigator(_ navigator: AudioNavigator, loadedTimeRangesDidChange ranges: [Range<Double>])
}

public extension AudioNavigatorDelegate {
    func navigator(_ navigator: AudioNavigator, playbackDidChange info: MediaPlaybackInfo) {}

    func navigator(_ navigator: AudioNavigator, shouldPlayNextResource info: MediaPlaybackInfo) -> Bool {
        true
    }

    func navigator(_ navigator: AudioNavigator, loadedTimeRangesDidChange ranges: [Range<Double>]) {}
}

/// Navigator for audio-based publications such as:
///
/// * Readium Audiobook
/// * ZAB (Zipped Audio Book)
@MainActor
public final class AudioNavigator: Navigator, Configurable, AudioSessionUser, Loggable {
    public weak var delegate: AudioNavigatorDelegate?

    public struct Configuration: Sendable {
        /// Initial set of setting preferences.
        public var preferences: AudioPreferences

        /// Provides default fallback values and ranges for the user settings.
        public var defaults: AudioDefaults

        /// Interval between two updates of the playback state.
        public var playbackRefreshInterval: TimeInterval

        /// Custom configuration for the audio session.
        public var audioSession: AudioSession.Configuration

        public init(
            preferences: AudioPreferences = AudioPreferences(),
            defaults: AudioDefaults = AudioDefaults(),
            playbackRefreshInterval: TimeInterval = 0.5,
            audioSession: AudioSession.Configuration = .init(
                category: .playback,
                mode: .spokenAudio,
                routeSharingPolicy: .longFormAudio
            )
        ) {
            self.preferences = preferences
            self.defaults = defaults
            self.playbackRefreshInterval = playbackRefreshInterval
            self.audioSession = audioSession
        }
    }

    public let publication: Publication

    public var readingOrder: [Link] {
        publication.readingOrder
    }

    private let initialLocation: Locator?
    private let config: Configuration
    private let audioSession: AudioSessionManaging

    public var audioConfiguration: AudioSession.Configuration {
        config.audioSession
    }

    public init(
        publication: Publication,
        initialLocation: Locator? = nil,
        config: Configuration = Configuration(),
        audioSession: AudioSessionManaging = AudioSession.shared
    ) {
        self.publication = publication
        self.initialLocation = initialLocation
        self.config = config
        self.audioSession = audioSession

        let durations = publication.readingOrder.map { $0.duration ?? 0 }
        let totalDuration = durations.reduce(0, +)

        self.durations = durations
        self.totalDuration = (totalDuration > 0) ? totalDuration : nil

        // The playback info reports the initial location until the first
        // resource is loaded.
        resourceIndex = initialLocation
            .flatMap { publication.readingOrder.firstIndexWithHREF($0.href) } ?? 0

        settings = AudioSettings(
            preferences: config.preferences,
            defaults: config.defaults
        )
    }

    isolated deinit {
        pendingPlayTask?.cancel()
        durationLoadTask?.cancel()
        didPlayToEndTimeTask?.cancel()
        if let rateDidChangeObserver {
            NotificationCenter.default.removeObserver(rateDidChangeObserver)
        }
        audioSession.end(with: self)
    }

    /// Returns whether the resource is currently playing or not.
    public var state: MediaPlaybackState {
        if pendingSeek?.resumesPlayback == true {
            // The player is paused during a seek, but the playback resumes
            // once it completes.
            return .loading
        }
        let state = MediaPlaybackState(player.timeControlStatus)
        if
            state == .playing,
            let item = player.currentItem,
            item.isPlaybackBufferEmpty, !item.isPlaybackLikelyToKeepUp
        {
            // As `automaticallyWaitsToMinimizeStalling` is disabled, the
            // player reports `.playing` even when it is stalled on an empty
            // buffer waiting for data.
            return .loading
        }
        if state == .paused {
            if pendingPlayTask != nil {
                // The player is paused until the audio session is ready, or
                // until the jump moving on from the end of a resource.
                return .loading
            }
            if hasReachedEndOfPublication {
                return .ended
            }
        }
        return state
    }

    /// Indicates whether the player is meant to be playing, even if it is
    /// currently stalled waiting for data.
    ///
    /// Unlike `state`, this reflects the playback intent, which is what we
    /// need to know when temporarily pausing the player to seek. This
    /// includes a `play()` still waiting for the audio session.
    private var isPlaybackRequested: Bool {
        pendingSeek?.resumesPlayback ?? (pendingPlayTask != nil || player.timeControlStatus != .paused)
    }

    /// Seek in progress, pausing the player until it completes.
    private struct PendingSeek {
        let id: Int
        /// Target in the current resource.
        var target: ResourceTime
        /// Whether the playback resumes once the seek completes.
        var resumesPlayback: Bool
    }

    /// Time in a resource, relative to its start or to its end.
    private enum ResourceTime {
        case fromStart(Double)
        case fromEnd(Double)

        /// Returns this time moved by `delta` seconds.
        func advanced(by delta: Double) -> ResourceTime {
            switch self {
            case let .fromStart(time): .fromStart(time + delta)
            case let .fromEnd(time): .fromEnd(time + delta)
            }
        }

        /// Returns the time from the start of a resource of the given
        /// `duration`, which may be out of its bounds.
        ///
        /// A time relative to the end falls back on the start of the resource
        /// when its duration is unknown.
        func timeFromStart(duration: Double?) -> Double {
            switch self {
            case let .fromStart(time): time
            case let .fromEnd(time): duration.map { $0 + time } ?? 0
            }
        }
    }

    private var pendingSeek: PendingSeek?
    private var lastSeekID = 0

    /// Current playback info.
    public var playbackInfo: MediaPlaybackInfo {
        MediaPlaybackInfo(
            resourceIndex: resourceIndex,
            state: state,
            time: currentTime,
            duration: resourceDuration
        )
    }

    /// Index of the current resource in the reading order.
    private var resourceIndex: Int = 0

    /// Exact duration reported by the current player item's asset, once
    /// loaded.
    private var loadedAssetDuration: Double?

    /// Task loading `loadedAssetDuration`, which can be awaited to get the
    /// exact duration of the current item.
    private var durationLoadTask: Task<Double?, Never>?

    /// A newly loaded asset duration is reported to the delegate only when it
    /// differs from the previous one by more than this many seconds.
    private static let assetDurationTolerance: Double = 0.1

    /// Starting time of the current resource, in the reading order.
    private var resourceStartingTime: Double? {
        durations[..<resourceIndex].reduce(0, +)
    }

    /// Duration in seconds of the current resource, if known.
    ///
    /// It is approximated from `Link.duration` until the asset reports the
    /// exact one.
    private var resourceDuration: Double? {
        (loadedAssetDuration ?? readingOrder[resourceIndex].duration)
            .flatMap { $0 > 0 ? $0 : nil }
    }

    /// Total duration in the publication.
    public private(set) var totalDuration: Double?

    /// Durations indexed by reading order position.
    private let durations: [Double]

    /// Current time in the current resource, or the target of the seek in
    /// progress.
    ///
    /// The target of a seek may be approximate until the exact duration of
    /// the resource is known.
    public var currentTime: Double {
        guard let target = pendingSeek?.target else {
            guard player.currentItem != nil else {
                // Nothing is loaded yet: the playback will start from the
                // initial location.
                return initialLocation.map { time(for: $0, duration: resourceDuration) } ?? 0
            }
            return player.currentTime().secondsOrZero
        }
        let targetTime = target.timeFromStart(duration: resourceDuration)
        return max(0, resourceDuration.map { min(targetTime, $0) } ?? targetTime)
    }

    /// Whether the current resource failed to load.
    private var hasFailedItem: Bool {
        player.currentItem?.status == .failed
    }

    /// Whether the playback is at the end of the current resource, reached by
    /// playing or seeking up to it.
    ///
    /// Reset by any seek or jump, including the one moving on to the next
    /// resource.
    private var hasReachedEndOfResource = false

    /// Whether the playback is at the end of the last resource, reached by
    /// playing or seeking up to it.
    private var hasReachedEndOfPublication: Bool {
        hasReachedEndOfResource && !canGoForward
    }

    /// Location to jump to before playing, when the player cannot play from
    /// its current position.
    private var locationToPlayFrom: Locator? {
        if hasFailedItem {
            // A failed player item never recovers on its own, so the resource
            // is loaded again.
            return currentLocation
        }
        if hasReachedEndOfResource {
            // Moves on to the next resource, or restarts from the beginning
            // of the publication after the last one.
            let index = canGoForward ? resourceIndex + 1 : 0
            return publication.locator(for: readingOrder[index])
        }
        return nil
    }

    /// Pending request to start the playback, reset once the player plays.
    private var pendingPlayTask: Task<Void, Never>? {
        willSet {
            pendingPlayTask?.cancel()
        }
    }

    /// Resumes or start the playback.
    ///
    /// After the end of a resource, the playback moves on to the next one, or
    /// restarts from the beginning of the publication after the last one. A
    /// resource which failed to load is loaded again.
    public func play() {
        if let location = locationToPlayFrom {
            pendingPlayTask = Task { @MainActor in
                guard !Task.isCancelled else {
                    return
                }
                await go(to: location, requestingPlayback: true)
            }
        } else if pendingSeek != nil {
            // The playback resumes once the seek completes.
            setPendingSeekResumesPlayback(true)
            return
        } else {
            playNow()
        }
        // The pending play is reported as `.loading`.
        playbackDidChange()
    }

    /// Starts the playback, even during a seek.
    ///
    /// Waits for the audio session before playing, unless `pause()` cancels it first.
    private func playNow() {
        pendingPlayTask = Task { @MainActor in
            guard !Task.isCancelled else {
                return
            }
            await audioSession.start(with: self, isPlaying: false)
            guard !Task.isCancelled else {
                return
            }

            if player.currentItem == nil {
                if let location = initialLocation {
                    await go(to: location)
                } else if let link = readingOrder.first {
                    await go(to: link)
                }
            }
            guard !Task.isCancelled else {
                return
            }
            player.playImmediately(atRate: Float(settings.speed))
            pendingPlayTask = nil
        }
    }

    /// Pauses the playback.
    public func pause() {
        // Pausing an already paused player doesn't change its rate, so we
        // need to reset the flag here. Otherwise a pause requested during an
        // interruption (e.g. with Siri) would be ignored when it ends.
        isPausedByInterruption = false
        // A pending play or seek would resume the playback otherwise.
        let hadPendingPlay = pendingPlayTask != nil
        pendingPlayTask = nil
        player.pause()
        setPendingSeekResumesPlayback(false)
        if hadPendingPlay {
            // The player doesn't report a pause when it was not playing yet.
            playbackDidChange()
        }
    }

    /// Stops the playback and ends the audio session.
    ///
    /// Use `play()` to resume the playback from the current position.
    public func stop() {
        pause()
        audioSession.end(with: self)
    }

    /// Toggles the playback.
    public func playPause() {
        if state.playsWhenReady {
            pause()
        } else {
            play()
        }
    }

    /// Seeks to the given time in the current resource.
    ///
    /// Seeking up to the end of the resource ends it, like playing up to it.
    public func seek(to time: Double) async {
        // There is nothing to seek in until a first resource is loaded.
        guard player.currentItem != nil else {
            return
        }
        if let duration = resourceDuration, time >= duration {
            // Seeks to the exact end, as `duration` may be approximate.
            await seekAcrossResources(to: .fromEnd(0))
            return
        }

        let seekID = beginSeek(to: .fromStart(time))
        await seekPlayer(to: time, seekID: seekID)
        await endSeek(seekID)
    }

    /// Seeks relatively from the current time, moving over to the adjacent
    /// resources when skipping past the start or the end of the current one.
    ///
    /// Skipping past the end of a resource ends it, like playing up to it.
    public func seek(by delta: Double) async {
        // There is nothing to seek in until a first resource is loaded.
        guard player.currentItem != nil else {
            return
        }
        // `delta` is added to the target of the seek in progress, which is
        // relative to the bounds of the resource, rather than to the current
        // time approximated from it.
        let target = pendingSeek?.target ?? .fromStart(currentTime)
        await seekAcrossResources(to: target.advanced(by: delta))
    }

    /// Seeks to `target` in the current resource, moving over to the adjacent
    /// resources while it is out of its bounds.
    private func seekAcrossResources(to target: ResourceTime) async {
        let seekID = beginSeek(to: target)
        guard let time = await moveToResource(containing: target, seekID: seekID) else {
            return
        }
        await seekPlayer(to: time, seekID: seekID)
        await endSeek(seekID)
    }

    /// Moves over to the resource containing `target`, which is relative to
    /// the current resource.
    ///
    /// The navigator moves on to the next resource only if the delegate allows
    /// it. Otherwise, or after the last resource, the playback is held at the
    /// end of the resource.
    ///
    /// Returns the time from the start of the resource moved to, or nil if a
    /// newer seek superseded this one.
    private func moveToResource(containing target: ResourceTime, seekID: Int) async -> Double? {
        var target = target

        while true {
            if case let .fromStart(time) = target, time <= 0 {
                // The start of a resource is always in its bounds. Before it,
                // the seek continues from the end of the previous resource.
                guard time < 0, canGoBackward, loadResource(at: resourceIndex - 1) else {
                    return 0
                }
                target = .fromEnd(time)
            }

            // `Link.duration` is only a hint, so the bounds of the resource
            // require the exact duration reported by the asset. We wait for
            // it if it is not loaded yet, reporting the approximate target in
            // the meantime.
            pendingSeek?.target = target
            if loadedAssetDuration == nil {
                locationDidChange()
            }
            let duration = await resolveResourceDuration()
            guard pendingSeek?.id == seekID else {
                return nil
            }

            let time = target.timeFromStart(duration: duration)
            if time < 0 {
                target = .fromStart(time)
                continue
            }
            guard let duration, time >= duration else {
                return time
            }

            // The delegate is given the playback info at the end of the
            // resource.
            pendingSeek?.target = .fromEnd(0)
            guard shouldPlayNextResource(), loadResource(at: resourceIndex + 1) else {
                // Holds the playback at the end of the current resource, until
                // `play()` moves on.
                hasReachedEndOfResource = true
                pause()

                return duration
            }
            target = .fromStart(time - duration)
        }
    }

    /// Updates whether the pending seek resumes the playback, notifying the
    /// delegate as it changes the reported `state`.
    private func setPendingSeekResumesPlayback(_ resumesPlayback: Bool) {
        guard
            let seek = pendingSeek,
            seek.resumesPlayback != resumesPlayback
        else {
            return
        }
        pendingSeek?.resumesPlayback = resumesPlayback
        playbackDidChange()
    }

    /// Pauses the player for a new seek to `target`, superseding any seek in
    /// progress.
    ///
    /// The playback resumes once the seek completes if it was already
    /// requested, or if the seek requests it with `requestingPlayback`.
    ///
    /// Returns the ID of the new seek.
    private func beginSeek(to target: ResourceTime, requestingPlayback: Bool = false) -> Int {
        hasReachedEndOfResource = false
        lastSeekID += 1
        pendingSeek = PendingSeek(id: lastSeekID, target: target, resumesPlayback: requestingPlayback || isPlaybackRequested)
        // A pending play would start the player during the seek otherwise.
        // The request is carried by `resumesPlayback` instead.
        pendingPlayTask = nil
        player.pause()
        return lastSeekID
    }

    /// Seeks the player to `time`, unless a newer seek superseded this one.
    ///
    /// Returns whether the seek finished.
    @discardableResult
    private func seekPlayer(to time: Double, seekID: Int) async -> Bool {
        guard pendingSeek?.id == seekID else {
            return false
        }
        pendingSeek?.target = .fromStart(time)
        locationDidChange()

        return await player.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
    }

    /// Resumes the playback if it was requested, then reports the actual
    /// position, unless a newer seek superseded this one.
    private func endSeek(_ seekID: Int) async {
        guard let seek = pendingSeek, seek.id == seekID else {
            return
        }
        if seek.resumesPlayback {
            playNow()
            await pendingPlayTask?.value
        }
        guard pendingSeek?.id == seekID else {
            return
        }
        pendingSeek = nil
        locationDidChange()
    }

    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var itemLikelyToKeepUpObserver: NSKeyValueObservation?
    private var timeObserverToken: TimeObserverToken?
    private var didPlayToEndTimeTask: Task<Void, Never>?
    private var rateDidChangeObserver: Any?

    /// Whether the player was paused by an audio session interruption, and
    /// should resume when it ends.
    private var isPausedByInterruption = false

    /// Whether the media loader reported an error for the current player
    /// item.
    ///
    /// Such an error makes the player item fail in turn, with an opaque
    /// AVFoundation error which is not reported on top of its cause.
    private var didReportLoadingError = false

    private lazy var mediaLoader: PublicationMediaLoader = {
        let loader = PublicationMediaLoader(publication: publication)
        loader.onLoadingError = { [weak self] href, error in
            Task { @MainActor in
                guard let self = self else {
                    return
                }
                if href.isEquivalentTo(self.readingOrder[self.resourceIndex].url()) {
                    self.didReportLoadingError = true
                }
                self.delegate?.navigator(self, didFailToLoadResourceAt: href, withError: error)
            }
        }
        return loader
    }()

    private lazy var player: AVPlayer = makePlayer()

    private func makePlayer() -> AVPlayer {
        let player = AVPlayer()
        player.allowsExternalPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false
        player.volume = Float(settings.volume)

        let periodicObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(
                seconds: config.playbackRefreshInterval,
                preferredTimescale: 1000
            ),
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.locationDidChange()
            }
        }

        timeObserverToken = TimeObserverToken(player: player, observer: periodicObserver)

        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.playbackDidChange()
            }
        }

        currentItemObserver = player.observe(\.currentItem, options: [.new, .old]) { [weak self] player, _ in
            let item = player.currentItem
            Task { @MainActor [weak self] in
                self?.observe(currentItem: item)
                self?.playbackDidChange()
            }
        }

        rateDidChangeObserver = NotificationCenter.default.addObserver(
            forName: AVPlayer.rateDidChangeNotification,
            object: player,
            queue: .main
        ) { [weak self] notification in
            // `Notification` is not `Sendable`, but it is safe to use here as
            // the block is called synchronously on the main queue.
            nonisolated(unsafe) let notification = notification

            // Handled synchronously, to be ordered with the audio session
            // interruption hooks which read `isPausedByInterruption`.
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }
                let reason = notification.userInfo?[AVPlayer.rateDidChangeReasonKey] as? AVPlayer.RateDidChangeReason
                self.isPausedByInterruption = self.player.rate == 0 && reason == .audioSessionInterrupted

                switch self.player.timeControlStatus {
                case .paused:
                    self.audioSession.user(self, didChangePlaying: false)
                case .waitingToPlayAtSpecifiedRate, .playing:
                    self.audioSession.user(self, didChangePlaying: true)
                @unknown default:
                    break
                }
            }
        }

        didPlayToEndTimeTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .AVPlayerItemDidPlayToEndTime) {
                guard
                    let self = self,
                    let currentItem = self.player.currentItem,
                    currentItem == (notification.object as? AVPlayerItem)
                else {
                    continue
                }

                // The player paused itself at the end of the resource, so
                // `play()` is needed to move on to the next one.
                self.hasReachedEndOfResource = true
                if self.shouldPlayNextResource() {
                    self.play()
                } else {
                    // The player might have reported its pause before the
                    // end of the resource was known.
                    self.playbackDidChange()
                }
            }
        }

        return player
    }

    private func observe(currentItem item: AVPlayerItem?) {
        itemLikelyToKeepUpObserver = item?.observe(\.isPlaybackLikelyToKeepUp) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.playbackDidChange()
            }
        }

        itemStatusObserver = item?.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else {
                return
            }

            let itemError = item.error

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                log(.error, "Failed to load the player item: \(String(describing: itemError))")
                guard !self.didReportLoadingError else {
                    return
                }
                let href = self.readingOrder[self.resourceIndex].url()
                let error: ReadError = itemError.flatMap { .wrap($0) }
                    ?? .decoding("The AVPlayerItem failed to load", cause: itemError)
                self.delegate?.navigator(self, didFailToLoadResourceAt: href, withError: error)
            }
        }
    }

    /// Returns whether to move on to the next resource at the end of the
    /// current one.
    ///
    /// The delegate is asked only when there is a next resource.
    private func shouldPlayNextResource() -> Bool {
        guard canGoForward else {
            return false
        }
        guard let delegate = delegate else {
            return true
        }

        return delegate.navigator(self, shouldPlayNextResource: playbackInfo)
    }

    public func audioSessionInterruptionDidBegin() {
        // `AVPlayer` pauses on its own, and reports it with the
        // `.audioSessionInterrupted` rate change reason.
    }

    public func audioSessionInterruptionDidEnd(shouldResume: Bool) {
        // The flag is cleared even when we don't resume, otherwise a later
        // interruption of the paused player (e.g. with Siri) would resume it.
        let wasPausedByInterruption = isPausedByInterruption
        isPausedByInterruption = false
        if shouldResume, wasPausedByInterruption {
            play()
        }
    }

    /// Notifies the delegate that the player state changed.
    private func playbackDidChange() {
        delegate?.navigator(self, playbackDidChange: playbackInfo)
    }

    /// Refreshes `currentLocation` and notifies the delegate, after the
    /// playback position or the resource duration changed.
    private func locationDidChange() {
        let locator = makeLocator(forTime: currentTime)
        currentLocation = locator
        delegate?.navigator(self, locationDidChange: locator)

        playbackDidChange()
    }

    private func makeLocator(forTime time: Double) -> Locator {
        let link = readingOrder[resourceIndex]

        var progression: Double?
        if let duration = resourceDuration, duration > 0 {
            progression = resourceDuration.map { time / max($0, 1) }
        }

        var totalProgression: Double? = nil
        if let totalDuration = totalDuration, totalDuration > 0, let startingTime = resourceStartingTime {
            totalProgression = (startingTime + time) / totalDuration
        }

        return Locator(
            href: link.url(),
            mediaType: link.mediaType ?? MediaType("audio/*")!,
            title: link.title,
            locations: Locator.Locations(
                fragments: ["t=\(time)"],
                progression: progression,
                totalProgression: totalProgression
            )
        )
    }

    /// Loads in the background the exact duration reported by the current
    /// asset, caching it in `loadedAssetDuration`.
    ///
    /// Loading it eagerly keeps `resourceDuration` synchronous, as awaiting the
    /// asset can take several seconds over HTTP.
    private func loadAssetDuration() {
        loadedAssetDuration = nil
        durationLoadTask?.cancel()
        durationLoadTask = nil

        guard let currentItem = player.currentItem else {
            return
        }

        durationLoadTask = Task { [weak self] in
            let seconds = try? await currentItem.asset.load(.duration).seconds

            // The item we loaded the duration for must still be the one being
            // played, otherwise `go(to:)` moved on while we were loading.
            guard
                !Task.isCancelled,
                let self = self,
                currentItem == self.player.currentItem,
                let seconds = seconds, seconds.isFinite
            else {
                return nil
            }

            let previousDuration = resourceDuration
            loadedAssetDuration = seconds

            if previousDuration.map({ abs(seconds - $0) > Self.assetDurationTolerance }) ?? true {
                locationDidChange()
            }

            return seconds
        }
    }

    // MARK: - Loaded Time Ranges

    private var lastLoadedTimeRanges: [Range<Double>] = []

    private lazy var loadedTimeRangesTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
        guard let self = self else {
            timer.invalidate()
            return
        }

        MainActor.assumeIsolated {
            let ranges: [Range<Double>] = (self.player.currentItem?.loadedTimeRanges ?? [])
                .map { value in
                    let range = value.timeRangeValue
                    let start = range.start.secondsOrZero
                    let duration = range.duration.secondsOrZero
                    return start ..< (start + duration)
                }

            guard ranges != self.lastLoadedTimeRanges else {
                return
            }

            self.lastLoadedTimeRanges = ranges
            self.delegate?.navigator(self, loadedTimeRangesDidChange: ranges)
        }
    }

    // MARK: - Navigator

    public private(set) var currentLocation: Locator?

    @discardableResult
    public func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool {
        await go(to: locator, requestingPlayback: false)
    }

    /// Jumps to `locator`.
    ///
    /// - Parameter requestingPlayback: Requests the playback to start once
    ///   the jump completes, like `play()` would. When false, the playback
    ///   resumes only if it was already requested. Either way, a `pause()`
    ///   during the jump cancels it.
    @discardableResult
    private func go(to locator: Locator, requestingPlayback: Bool) async -> Bool {
        guard let newResourceIndex = readingOrder.firstIndexWithHREF(locator.href) else {
            return false
        }
        let link = readingOrder[newResourceIndex]

        // Sets the target right away, so that notifications sent before the
        // seek don't report the start of the new resource. It may be
        // approximated from the progression until the exact duration of the
        // resource is known.
        let seekID = beginSeek(
            to: .fromStart(time(for: locator, duration: link.duration)),
            requestingPlayback: requestingPlayback
        )

        currentLocation = locator
        guard loadResource(at: newResourceIndex) else {
            // The playback doesn't resume after a failed jump.
            if pendingSeek?.id == seekID {
                pendingSeek = nil
                playbackDidChange()
            }
            return false
        }

        // `Link.duration` is only a hint, so converting a progression into a
        // time requires the exact duration reported by the asset. We wait for
        // it if it is not loaded yet.
        let convertsProgression = locator.locations.time?.begin == nil
            && (locator.locations.progression ?? 0) > 0
        let duration = convertsProgression
            ? await resolveResourceDuration()
            : resourceDuration

        let targetTime = time(for: locator, duration: duration)
        let finished = await seekPlayer(to: targetTime, seekID: seekID)
        if finished {
            delegate?.navigator(self, didJumpTo: locator)
        }

        await endSeek(seekID)
        return true
    }

    /// Loads the resource at `index` in the player, unless it is the current
    /// one. A resource which failed to load is loaded again, as a failed
    /// player item never recovers on its own.
    ///
    /// Returns whether the resource is loaded in the player.
    private func loadResource(at index: Int) -> Bool {
        guard player.currentItem == nil || resourceIndex != index || hasFailedItem else {
            return true
        }

        let link = readingOrder[index]
        do {
            log(.info, "Loads \(link.href)")
            let asset = try mediaLoader.makeAsset(for: link)
            player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            resourceIndex = index
            didReportLoadingError = false
            loadAssetDuration()
            loadedTimeRangesTimer.fire()
            delegate?.navigator(self, loadedTimeRangesDidChange: [])
            return true
        } catch {
            log(.error, error)
            return false
        }
    }

    /// Returns the duration of the current resource, waiting for its asset
    /// to report the exact one if it is not loaded yet.
    ///
    /// Falls back on the approximate `Link.duration` when the asset cannot
    /// report its duration.
    private func resolveResourceDuration() async -> Double? {
        if loadedAssetDuration == nil, let task = durationLoadTask {
            // A cancelled task means that another resource was loaded in the
            // meantime, not that the duration is unavailable.
            if await task.value == nil, !task.isCancelled {
                log(.warning, "Asset duration unavailable, falling back on the approximate `Link.duration`")
            }
        }
        return resourceDuration
    }

    /// Returns the time targeted by `locator` in its resource, converting its
    /// progression with the given resource `duration`.
    private func time(for locator: Locator, duration: Double?) -> Double {
        if let begin = locator.locations.time?.begin {
            return begin
        }
        guard let progression = locator.locations.progression, progression > 0 else {
            return 0
        }
        return (duration ?? 0) * progression
    }

    public func go(to link: Link, options: NavigatorGoOptions) async -> Bool {
        guard let locator = publication.locator(for: link) else {
            return false
        }
        return await go(to: locator, options: options)
    }

    /// Indicates whether the navigator can go to the next content portion
    /// (e.g. page or audiobook resource).
    public var canGoForward: Bool {
        readingOrder.indices.contains(resourceIndex + 1)
    }

    /// Indicates whether the navigator can go to the next content portion
    /// (e.g. page or audiobook resource).
    public var canGoBackward: Bool {
        readingOrder.indices.contains(resourceIndex - 1)
    }

    public func goForward(options: NavigatorGoOptions) async -> Bool {
        await goToResourceIndex(resourceIndex + 1, options: options)
    }

    public func goBackward(options: NavigatorGoOptions) async -> Bool {
        await goToResourceIndex(resourceIndex - 1, options: options)
    }

    @discardableResult
    private func goToResourceIndex(_ index: Int, options: NavigatorGoOptions) async -> Bool {
        guard readingOrder.indices ~= index else {
            return false
        }
        return await go(to: readingOrder[index], options: options)
    }

    // MARK: - Configurable

    public private(set) var settings: AudioSettings

    public func submitPreferences(_ preferences: AudioPreferences) {
        settings = AudioSettings(
            preferences: preferences,
            defaults: config.defaults
        )

        player.volume = Float(settings.volume)

        // We don't directly change `player.rate`, because it might be 0 when the player is paused. `settings.speed`
        // is actually the default speed while playing.
        if player.timeControlStatus != .paused {
            player.rate = Float(settings.speed)
        }
    }

    public func editor(of preferences: AudioPreferences) -> AudioPreferencesEditor {
        AudioPreferencesEditor(
            initialPreferences: preferences,
            defaults: config.defaults
        )
    }
}

private extension MediaPlaybackState {
    init(_ timeControlStatus: AVPlayer.TimeControlStatus) {
        switch timeControlStatus {
        case .paused:
            self = .paused
        case .waitingToPlayAtSpecifiedRate:
            self = .loading
        case .playing:
            self = .playing
        @unknown default:
            self = .loading
        }
    }
}

private extension CMTime {
    var secondsOrZero: Double {
        isNumeric ? seconds : 0
    }
}

private final class TimeObserverToken {
    private let player: AVPlayer
    private let observer: Any

    init(player: AVPlayer, observer: Any) {
        self.player = player
        self.observer = observer
    }

    deinit {
        player.removeTimeObserver(observer)
    }
}
