//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import ReadiumShared

/// Status of a played media resource.
public enum MediaPlaybackState {
    case paused
    case loading
    case playing
}

/// Holds metadata about a played media resource.
public struct MediaPlaybackInfo {
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

    /// Called when the navigator finished playing the current resource.
    /// Returns whether the next resource should be played. Default is true.
    func navigator(_ navigator: AudioNavigator, shouldPlayNextResource info: MediaPlaybackInfo) -> Bool

    /// Called when the ranges of buffered media data change.
    /// Warning: They may be discontinuous.
    func navigator(_ navigator: AudioNavigator, loadedTimeRangesDidChange ranges: [Range<Double>])
}

public extension AudioNavigatorDelegate {
    func navigator(_ navigator: AudioNavigator, playbackDidChange info: MediaPlaybackInfo) {}

    func navigator(_ navigator: AudioNavigator, shouldPlayNextResource info: MediaPlaybackInfo) -> Bool { true }

    func navigator(_ navigator: AudioNavigator, loadedTimeRangesDidChange ranges: [Range<Double>]) {}
}

/// Navigator for audio-based publications such as:
///
/// * Readium Audiobook
/// * ZAB (Zipped Audio Book)
public final class AudioNavigator: Navigator, Configurable, AudioSessionUser, Loggable {
    public weak var delegate: AudioNavigatorDelegate?

    public struct Configuration {
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

    public nonisolated let publication: Publication
    private let initialLocation: Locator?
    private let config: Configuration

    public var audioConfiguration: AudioSession.Configuration { config.audioSession }

    public init(
        publication: Publication,
        initialLocation: Locator? = nil,
        config: Configuration = Configuration()
    ) {
        self.publication = publication
        self.initialLocation = initialLocation
        self.config = config

        let durations = publication.readingOrder.map { $0.duration ?? 0 }
        let totalDuration = durations.reduce(0, +)

        self.durations = durations
        self.totalDuration = (totalDuration > 0) ? totalDuration : nil

        settings = AudioSettings(
            preferences: config.preferences,
            defaults: config.defaults
        )
    }

    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }

        playTask?.cancel()
        AudioSession.shared.end(for: self)
    }

    /// Returns whether the resource is currently playing or not.
    public var state: MediaPlaybackState {
        MediaPlaybackState(player.timeControlStatus)
    }

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

    /// Starting time of the current resource, in the reading order.
    private var resourceStartingTime: Double? {
        durations[..<resourceIndex].reduce(0, +)
    }

    /// Duration in seconds in the current resource.
    private var resourceDuration: Double? {
        if let duration = player.currentItem?.duration, duration.isNumeric {
            return duration.secondsOrZero
        } else {
            return publication.readingOrder[resourceIndex].duration
        }
    }

    /// Total duration in the publication.
    public private(set) var totalDuration: Double?

    /// Durations indexed by reading order position.
    private let durations: [Double]

    public var currentTime: Double {
        player.currentTime().secondsOrZero
    }

    private var playTask: Task<Void, Never>? {
        willSet {
            playTask?.cancel()
        }
    }

    /// Resumes or start the playback.
    public func play() {
        playTask = Task { @MainActor in
            AudioSession.shared.start(with: self, isPlaying: false)

            if player.currentItem == nil {
                if let location = initialLocation {
                    await go(to: location)
                } else if let link = publication.readingOrder.first {
                    await go(to: link)
                }
            }
            player.playImmediately(atRate: Float(settings.speed))
        }
    }

    /// Pauses the playback.
    public func pause() {
        player.pause()
    }

    /// Toggles the playback.
    public func playPause() {
        switch state {
        case .loading, .playing:
            pause()
        case .paused:
            play()
        }
    }

    /// Seeks to the given time in the current resource.
    public func seek(to time: Double) async {
        let wasPlaying = (state == .playing)
        pause()

        await player.seek(to: CMTime(seconds: time, preferredTimescale: 1000))

        if wasPlaying {
            play()
        }
    }

    /// Seeks relatively from the current time in the current resource.
    public func seek(by delta: Double) async {
        await seek(to: currentTime + delta)
    }

    private var rateObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?
    private var timeObserver: Any?

    private lazy var mediaLoader = PublicationMediaLoader(publication: publication)

    private lazy var player: AVPlayer = {
        let player = AVPlayer()
        player.allowsExternalPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false
        player.volume = Float(settings.volume)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(
                seconds: config.playbackRefreshInterval,
                preferredTimescale: 1000
            ),
            queue: .main
        ) { [weak self] time in
            if let self = self {
                let time = time.secondsOrZero
                self.playbackDidChange(time)
            }
        }

        rateObserver = player.observe(\.rate, options: [.new, .old]) { [weak self] player, _ in
            guard let self = self else {
                return
            }

            let session = AudioSession.shared
            switch player.timeControlStatus {
            case .paused:
                session.user(self, didChangePlaying: false)
            case .waitingToPlayAtSpecifiedRate, .playing:
                session.user(self, didChangePlaying: true)
            @unknown default:
                break
            }
        }

        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] _, _ in
            self?.playbackDidChange()
        }

        currentItemObserver = player.observe(\.currentItem, options: [.new, .old]) { [weak self] _, _ in
            self?.playbackDidChange()
        }

        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
            guard
                let self = self,
                let currentItem = player.currentItem,
                currentItem == (notification.object as? AVPlayerItem)
            else {
                return
            }

            self.shouldPlayNextResource { playNext in
                Task {
                    if playNext, await self.goForward() {
                        self.play()
                    }
                }
            }
        }

        return player
    }()

    private func shouldPlayNextResource(completion: @escaping (Bool) -> Void) {
        guard let delegate = delegate else {
            completion(true)
            return
        }

        makePlaybackInfo { info in
            completion(delegate.navigator(self, shouldPlayNextResource: info))
        }
    }

    private func playbackDidChange(_ time: Double? = nil) {
        if let time = time {
            let locator = makeLocator(forTime: time)
            currentLocation = locator
            Task { @MainActor in
                delegate?.navigator(self, locationDidChange: locator)
            }
        }

        makePlaybackInfo(forTime: time) { info in
            self.delegate?.navigator(self, playbackDidChange: info)
        }
    }

    /// A deadlock can occur when loading HTTP assets and creating the playback info from the main thread.
    /// To fix this, this is an asynchronous operation.
    private func makePlaybackInfo(forTime time: Double? = nil, completion: @escaping @MainActor (MediaPlaybackInfo) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            let info = MediaPlaybackInfo(
                resourceIndex: self.resourceIndex,
                state: self.state,
                time: time ?? self.currentTime,
                duration: self.resourceDuration
            )

            DispatchQueue.main.async {
                completion(info)
            }
        }
    }

    private func makeLocator(forTime time: Double) -> Locator {
        let link = publication.readingOrder[resourceIndex]

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

    // MARK: - Loaded Time Ranges

    private var lastLoadedTimeRanges: [Range<Double>] = []

    private lazy var loadedTimeRangesTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
        guard let self = self else {
            timer.invalidate()
            return
        }

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
        Task { @MainActor in
            self.delegate?.navigator(self, loadedTimeRangesDidChange: ranges)
        }
    }

    // MARK: - Navigator

    public private(set) var currentLocation: Locator?

    public func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool {
        let wasPlaying = (state == .playing)
        pause()

        guard let newResourceIndex = publication.readingOrder.firstIndexWithHREF(locator.href) else {
            return false
        }
        let link = publication.readingOrder[newResourceIndex]

        do {
            currentLocation = locator
            // Loads resource
            if player.currentItem == nil || resourceIndex != newResourceIndex {
                log(.info, "Starts playing \(link.href)")
                let asset = try mediaLoader.makeAsset(for: link)
                player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                resourceIndex = newResourceIndex
                loadedTimeRangesTimer.fire()
                await delegate?.navigator(self, loadedTimeRangesDidChange: [])
            }

            // Seeks to time
            let time = locator.locations.time?.begin ?? ((resourceDuration ?? 0) * (locator.locations.progression ?? 0))

            let finished = await player.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
            if finished {
                await delegate?.navigator(self, didJumpTo: locator)
            }

            if wasPlaying {
                play()
            }

            return true

        } catch {
            log(.error, error)
            return false
        }
    }

    public func go(to link: Link, options: NavigatorGoOptions) async -> Bool {
        guard let locator = await publication.locate(link) else {
            return false
        }
        return await go(to: locator, options: options)
    }

    /// Indicates whether the navigator can go to the next content portion
    /// (e.g. page or audiobook resource).
    public var canGoForward: Bool {
        publication.readingOrder.indices.contains(resourceIndex + 1)
    }

    /// Indicates whether the navigator can go to the next content portion
    /// (e.g. page or audiobook resource).
    public var canGoBackward: Bool {
        publication.readingOrder.indices.contains(resourceIndex - 1)
    }

    public func goForward(options: NavigatorGoOptions) async -> Bool {
        await goToResourceIndex(resourceIndex + 1, options: options)
    }

    public func goBackward(options: NavigatorGoOptions) async -> Bool {
        await goToResourceIndex(resourceIndex - 1, options: options)
    }

    @discardableResult
    private func goToResourceIndex(_ index: Int, options: NavigatorGoOptions) async -> Bool {
        guard publication.readingOrder.indices ~= index else {
            return false
        }
        return await go(to: publication.readingOrder[index], options: options)
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
        if state != .paused {
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
