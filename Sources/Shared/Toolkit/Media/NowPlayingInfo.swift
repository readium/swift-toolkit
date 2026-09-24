//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import MediaPlayer
import UIKit

/// Manages the Now Playing media item displayed on the lock screen.
///
/// Simply set the `playback` and `media` properties when needed. Any change is
/// shown immediately, except a progress of the elapsed time matching the one
/// extrapolated by the system from the playback rate, which is not pushed to
/// avoid updating the Now Playing screen needlessly.
///
/// Setting a different `media` resets the `playback`.
@MainActor
public final class NowPlayingInfo {
    public static let shared = NowPlayingInfo()

    public struct Media: Equatable, Sendable {
        /// The title (or name) of the media item.
        public var title: String

        /// The performing artist(s) for a media item.
        public var artist: String?

        /// The artwork image for the media item.
        public var artwork: UIImage?

        /// The total number of chapters in the now-playing item.
        public var chapterCount: Int?

        public init(title: String, artist: String? = nil, artwork: UIImage? = nil, chapterCount: Int? = nil) {
            self.title = title
            self.artist = artist
            self.artwork = artwork
            self.chapterCount = chapterCount
        }

        @available(*, unavailable, message: "Use `NowPlayingInfo.Playback.chapterNumber` instead.")
        public var chapterNumber: Int? {
            get { fatalError() }
            set { fatalError() }
        }

        @available(*, unavailable, message: "Use `NowPlayingInfo.Playback.chapterNumber` to set the chapterNumber.")
        public init(title: String, artist: String? = nil, artwork: UIImage? = nil, chapterCount: Int? = nil, chapterNumber: Int?) {
            fatalError()
        }
    }

    public struct Playback: Equatable, Sendable {
        /// The number corresponding to the chapter currently being played.
        public var chapterNumber: Int?

        /// The playback duration of the media item, in seconds.
        public var duration: Double?

        /// The elapsed time of the now playing item, in seconds.
        public var elapsedTime: Double?

        /// The effective playback rate of the now-playing item, with a value
        /// of 1.0 indicating the normal playback rate.
        ///
        /// The system extrapolates the elapsed time from it, so it must be 0
        /// while the playback is not progressing, e.g. paused or buffering,
        /// even if the speed setting is different.
        public var rate: Double?

        public init(chapterNumber: Int? = nil, duration: Double? = nil, elapsedTime: Double? = nil, rate: Double? = nil) {
            self.chapterNumber = chapterNumber
            self.duration = duration
            self.elapsedTime = elapsedTime
            self.rate = rate
        }

        public mutating func clear() {
            chapterNumber = nil
            duration = nil
            elapsedTime = nil
            rate = nil
        }
    }

    /// Information about the current media item being played.
    ///
    /// Setting a different value resets the `playback`.
    public var media: Media? {
        didSet {
            guard oldValue != media else {
                return
            }
            mpArtwork = media?.artwork.map { image in
                Self.makeArtwork(image: image)
            }
            _playback.clear()
            push()
        }
    }

    /// Playback information about the rendition of the current media.
    ///
    /// Ignored until a `media` is set.
    public var playback: Playback {
        get { _playback }
        set {
            guard media != nil, _playback != newValue else {
                return
            }
            _playback = newValue
            if pushFilter.shouldPush(newValue) {
                push()
            }
        }
    }

    private var _playback = Playback()

    private init() {}

    /// Skips the playback updates which the system extrapolates on its own.
    private var pushFilter = NowPlayingPushFilter()

    /// Clears the Now Playing infos.
    public func clear() {
        media = nil
    }

    private nonisolated static func makeArtwork(image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ in image })
    }

    private var mpArtwork: MPMediaItemArtwork?

    /// Updates the Now Playing screen.
    private func push() {
        guard let media else {
            pushFilter.reset()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        pushFilter.didPush(playback)

        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = media.title
        if let artist = media.artist {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let mpArtwork {
            info[MPMediaItemPropertyArtwork] = mpArtwork
        }
        if let chapterCount = media.chapterCount {
            info[MPNowPlayingInfoPropertyChapterCount] = chapterCount
        }

        if let chapterNumber = playback.chapterNumber {
            info[MPNowPlayingInfoPropertyChapterNumber] = chapterNumber
        }
        if let duration = playback.duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let elapsedTime = playback.elapsedTime {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        }
        if let rate = playback.rate {
            info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
