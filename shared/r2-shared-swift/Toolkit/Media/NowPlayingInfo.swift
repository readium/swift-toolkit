//
//  NowPlayingInfo.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 28/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import MediaPlayer
import UIKit

/// Manages the Now Playing media item displayed on the lock screen.
///
/// Simply set the `playback` and `media` properties when needed, the calls will automatically be
/// throttled to avoid updating the Now Playing screen too frequently.
///
/// **WARNING:** This API is experimental and may change or be removed in a future release without
/// notice. Use with caution.
@available(iOS 10.0, *)
public final class _NowPlayingInfo {
    
    public static let shared = _NowPlayingInfo()

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
    
    /// Throttle delay used to avoid updating the Now Playing screen too frequently, in seconds.
    public var throttleDelay: TimeInterval = 1

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
            setNeedsUpdate()
        }
    }
     
    /// Playback information about the rendition of the current media.
    public var playback: Playback = Playback() {
        didSet {
            guard oldValue != playback else {
                return
            }
            setNeedsUpdate()
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
    
    private var needsUpdate: Bool = false
    private func setNeedsUpdate() {
        guard !needsUpdate else {
            return
        }
        needsUpdate = true
        DispatchQueue.main.asyncAfter(deadline: .now() + throttleDelay) {
            self.update()
        }
    }
    
    private func update() {
        needsUpdate = false
        
        var info = [String: Any]()
        if let media = media {
            info[MPMediaItemPropertyTitle] = media.title
            if let artist = media.artist {
                info[MPMediaItemPropertyArtist] = artist
            }
            if let mpArtwork = mpArtwork {
                info[MPMediaItemPropertyArtwork] = mpArtwork
            }
            if let chapterCount = media.chapterCount {
                info[MPNowPlayingInfoPropertyChapterCount] = chapterCount
            }
            if let chapterNumber = media.chapterNumber {
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
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

}
