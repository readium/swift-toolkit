//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A bounded region of an audio file to play, with optional markers.
///
/// The player plays from `start` to `end`, firing a delegate callback each
/// time a marker position is reached.
public struct AudioClip: Hashable, Sendable {
    /// A labelled position within an ``AudioClip`` at which the player notifies
    /// its delegate.
    public struct Marker: Hashable, Sendable {
        /// Unique identifier for this marker.
        public var id: UUID

        /// Position of the marker in seconds from the beginning of the audio
        /// resource, within the enclosing clip's start-end range.
        public var time: TimeInterval

        public init(
            id: UUID = UUID(),
            time: TimeInterval
        ) {
            self.id = id
            self.time = time
        }
    }

    /// Publication link for the audio resource, carrying the URL and media type.
    public var link: Link

    /// Start of the clip, in seconds from the beginning of the resource.
    public var start: TimeInterval

    /// End of the clip, in seconds from the beginning of the resource.
    ///
    /// When `nil`, the clip plays to the end of the audio resource.
    public var end: TimeInterval?

    /// Markers at which the player notifies the delegate.
    ///
    /// Positions are expressed in seconds from the beginning of the resource,
    /// within the start-end range.
    public var markers: [Marker]

    public init(
        link: Link,
        start: TimeInterval,
        end: TimeInterval? = nil,
        markers: [Marker] = []
    ) {
        self.link = link
        self.start = start
        self.end = end
        self.markers = markers
    }
}
