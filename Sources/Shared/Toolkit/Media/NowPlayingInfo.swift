//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import MediaPlayer
import UIKit

/// Manages the Now Playing media item displayed on the lock screen.
///
/// Simply set the `playback` and `media` properties when needed, the calls will automatically be
/// throttled to avoid updating the Now Playing screen too frequently.
public final class NowPlayingInfo {
    public static let shared = NowPlayingInfo()

    public struct Media: Equatable {
        /// The title (or name) of the media item.
        public var title: String
        /// The performing artist(s) for a media item.
        public var artist: String?
        /// The artwork image for the media item.
        public var artwork: UIImage?
        /// The total number of chapters in the now-playing item.
        public var chapterCount: Int?
        /// The number corresponding to the chapter currently being played.
        public var chapterNumber: Int?

        public init(title: String, artist: String? = nil, artwork: UIImage? = nil, chapterCount: Int? = nil, chapterNumber: Int? = nil) {
            self.title = title
            self.artist = artist
            self.artwork = artwork
            self.chapterCount = chapterCount
            self.chapterNumber = chapterNumber
        }
    }

    public struct Playback: Equatable {
        /// The playback duration of the media item, in seconds.
        public var duration: Double?
        /// The elapsed time of the now playing item, in seconds.
        public var elapsedTime: Double?
        /// The playback rate of the now-playing item, with a value of 1.0 indicating the normal
        /// playback rate.
        public var rate: Double?

        public init(duration: Double? = nil, elapsedTime: Double? = nil, rate: Double? = nil) {
            self.duration = duration
            self.elapsedTime = elapsedTime
            self.rate = rate
        }

        public mutating func clear() {
            duration = nil
            elapsedTime = nil
            rate = nil
        }
    }

    /// Information about the current media item being played.
    public var media: Media? {
        didSet {
            guard oldValue != media else {
                return
            }
            mpArtwork = media?.artwork.map { image in
                MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ in image })
            }
            playback.clear()
            update()
        }
    }

    /// Playback information about the rendition of the current media.
    public var playback: Playback = .init() {
        didSet {
            guard oldValue != playback else {
                return
            }
            update()
        }
    }

    private init() {}

    /// Clears the Now Playing infos.
    public func clear() {
        media = nil
        playback.clear()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private var mpArtwork: MPMediaItemArtwork?

    /// Updates the Now Playing screen, maximum once per second.
    private lazy var update = throttle(duration: 1) { [weak self] in
        var info = [String: Any]()
        if let self = self, let media = self.media {
            info[MPMediaItemPropertyTitle] = media.title
            if let artist = media.artist {
                info[MPMediaItemPropertyArtist] = artist
            }
            if let mpArtwork = self.mpArtwork {
                info[MPMediaItemPropertyArtwork] = mpArtwork
            }
            if let chapterCount = media.chapterCount {
                info[MPNowPlayingInfoPropertyChapterCount] = chapterCount
            }
            if let chapterNumber = media.chapterNumber {
                info[MPNowPlayingInfoPropertyChapterNumber] = chapterNumber
            }

            if let duration = self.playback.duration {
                info[MPMediaItemPropertyPlaybackDuration] = duration
            }
            if let elapsedTime = self.playback.elapsedTime {
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
            }
            if let rate = self.playback.rate {
                info[MPNowPlayingInfoPropertyPlaybackRate] = rate
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
