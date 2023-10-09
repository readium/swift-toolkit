//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import R2Shared

public protocol _AudioNavigatorDelegate: _MediaNavigatorDelegate {}

/// Navigator for audio-based publications such as:
///
/// * Readium Audiobook
/// * ZAB (Zipped Audio Book)
///
/// **WARNING:** This API is experimental and may change or be removed in a
/// future release without notice. Use with caution.
open class _AudioNavigator: _MediaNavigator, AudioSessionUser, Loggable {
    public weak var delegate: _AudioNavigatorDelegate?

    public let publication: Publication
    private let initialLocation: Locator?
    public let audioConfiguration: AudioSession.Configuration

    public init(
        publication: Publication,
        initialLocation: Locator? = nil,
        audioConfig: AudioSession.Configuration = .init(
            category: .playback,
            mode: .default,
            routeSharingPolicy: .longForm,
            options: []
        )
    ) {
        self.publication = publication
        self.initialLocation = initialLocation
            ?? publication.readingOrder.first.flatMap { publication.locate($0) }
        audioConfiguration = audioConfig

        let durations = publication.readingOrder.map { $0.duration ?? 0 }
        let totalDuration = durations.reduce(0, +)

        self.durations = durations
        self.totalDuration = (totalDuration > 0) ? totalDuration : nil
    }

    deinit {
        AudioSession.shared.end(for: self)
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

    private var rateObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?

    private lazy var mediaLoader = PublicationMediaLoader(publication: publication)

    private lazy var player: AVPlayer = {
        let player = AVPlayer()
        player.allowsExternalPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false

        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000), queue: .main) { [weak self] time in
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
                if playNext, self.goForward() {
                    self.play()
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
            delegate?.navigator(self, locationDidChange: locator)
        }

        makePlaybackInfo(forTime: time) { info in
            self.delegate?.navigator(self, playbackDidChange: info)
        }
    }

    /// A deadlock can occur when loading HTTP assets and creating the playback info from the main thread.
    /// To fix this, this is an asynchronous operation.
    private func makePlaybackInfo(forTime time: Double? = nil, completion: @escaping (MediaPlaybackInfo) -> Void) {
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
            href: link.href,
            type: link.type ?? "audio/*",
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
        self.delegate?.navigator(self, loadedTimeRangesDidChange: ranges)
    }

    // MARK: - Navigator

    public private(set) var currentLocation: Locator?

    @discardableResult
    public func go(to locator: Locator, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        guard let newResourceIndex = publication.readingOrder.firstIndex(withHREF: locator.href) else {
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
                delegate?.navigator(self, loadedTimeRangesDidChange: [])
            }

            // Seeks to time
            let time = locator.time(forDuration: resourceDuration) ?? 0
            player.seek(to: CMTime(seconds: time, preferredTimescale: 1000)) { [weak self] finished in
                if let self = self, finished {
                    self.delegate?.navigator(self, didJumpTo: locator)
                }
                DispatchQueue.main.async(execute: completion)
            }
            return true
        } catch {
            log(.error, error)
            return false
        }
    }

    @discardableResult
    public func go(to link: Link, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        guard let locator = publication.locate(link) else {
            return false
        }
        return go(to: locator, animated: animated, completion: completion)
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

    @discardableResult
    public func goForward(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        goToResourceIndex(resourceIndex + 1, animated: animated, completion: completion)
    }

    @discardableResult
    public func goBackward(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        goToResourceIndex(resourceIndex - 1, animated: animated, completion: completion)
    }

    @discardableResult
    private func goToResourceIndex(_ index: Int, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        guard publication.readingOrder.indices ~= index else {
            return false
        }
        return go(to: publication.readingOrder[index], animated: animated, completion: completion)
    }

    // MARK: - MediaNavigator

    public var currentTime: Double {
        player.currentTime().secondsOrZero
    }

    public var volume: Double {
        get { Double(player.volume) }
        set {
            assert(0 ... 1 ~= newValue)
            player.volume = Float(newValue)
        }
    }

    public var rate: Double = 1 {
        // We don't alias to `player.rate`, because it might be 0 when the player is paused. `rate`
        // is actually the default rate while playing.
        didSet {
            assert(rate >= 0)
            if state != .paused {
                player.rate = Float(rate)
            }
        }
    }

    public var state: MediaPlaybackState {
        MediaPlaybackState(player.timeControlStatus)
    }

    public func play() {
        AudioSession.shared.start(with: self, isPlaying: false)

        if player.currentItem == nil, let location = initialLocation {
            go(to: location)
        }
        player.playImmediately(atRate: Float(rate))
    }

    public func pause() {
        player.pause()
    }

    public func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
    }

    public func seek(by delta: Double) {
        seek(to: currentTime + delta)
    }
}

private extension Locator {
    private static let timeFragmentRegex = try! NSRegularExpression(pattern: #"t=(\d+(?:\.\d+)?)"#)

    // FIXME: Should probably be in `Locator` itself.
    func time(forDuration duration: Double? = nil) -> Double? {
        if let progression = locations.progression, let duration = duration {
            return progression * duration
        } else {
            for fragment in locations.fragments {
                let range = NSRange(fragment.startIndex ..< fragment.endIndex, in: fragment)
                if let match = Self.timeFragmentRegex.firstMatch(in: fragment, range: range) {
                    let matchRange = match.range(at: 1)
                    if matchRange.location != NSNotFound, let range = Range(matchRange, in: fragment) {
                        return Double(fragment[range])
                    }
                }
            }
        }
        return nil
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
