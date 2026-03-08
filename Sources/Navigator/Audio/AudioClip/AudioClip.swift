//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A list of segments to play in an audio file.
public struct AudioClip: Hashable, Sendable {
    /// Publication link for the audio resource, carrying the URL and media type.
    public let link: Link

    /// Segments to play in the audio file.
    public let segments: [Segment]

    /// Start of the clip, in seconds from the beginning of the resource.
    public var start: TimeInterval {
        segments.first?.start ?? 0
    }

    /// End of the clip, in seconds from the beginning of the resource.
    ///
    /// When `nil`, the clip plays to the end of the audio resource.
    public var end: TimeInterval? {
        segments.last?.end
    }

    /// A segment within an ``AudioClip``.
    public struct Segment: Hashable, Sendable {
        /// Unique identifier for this segment.
        public var id: UUID

        /// Start of the segment, in seconds from the beginning of the resource.
        public var start: TimeInterval

        /// End of the segment, in seconds from the beginning of the resource.
        ///
        /// When `nil`, the segment ends at the next segment, or the end of the
        /// audio file.
        public var end: TimeInterval?

        public init(
            id: UUID = UUID(),
            start: TimeInterval,
            end: TimeInterval?
        ) {
            self.id = id
            self.start = start
            self.end = end
        }
    }

    /// Creates an ``AudioClip`` with segments validated and normalized:
    ///
    /// - Segments are sorted by their `start` property.
    /// - Segments with duplicate `start` values are deduplicated (first one wins).
    /// - Overlapping segments have the earlier segment's `end` set to `nil` so it
    ///   continues until the next segment begins.
    public init(
        link: Link,
        segments: [Segment]
    ) {
        let sorted = segments.sorted { $0.start < $1.start }

        var normalized: [Segment] = []
        for segment in sorted {
            // Deduplicate segments with the same start (keep first).
            if normalized.last?.start == segment.start {
                continue
            }
            // Fix overlap: if the previous segment's end is past this segment's start,
            // clear it so it naturally ends when this one begins.
            if var previous = normalized.last, let previousEnd = previous.end, previousEnd > segment.start {
                previous.end = nil
                normalized[normalized.count - 1] = previous
            }
            normalized.append(segment)
        }

        self.link = link
        self.segments = normalized
    }
}
