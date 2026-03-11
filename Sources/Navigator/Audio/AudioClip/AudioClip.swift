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

        /// A segment is valid when it has positive length: `end` is `nil`
        /// (open-ended) or strictly greater than `start`.
        public var isValid: Bool {
            end == nil || end! > start
        }

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

    /// Creates an ``AudioClip`` with segments validated and normalized.
    public init(
        link: Link,
        segments: [Segment]
    ) {
        var normalized = AudioClip.normalizeSegments(segments) { $0 }

        // Segment-specific overlap resolution: clear the end of an earlier
        // segment when a later one begins before it would finish.
        for i in normalized.indices.dropFirst() {
            if let previousEnd = normalized[i - 1].end, previousEnd > normalized[i].start {
                normalized[i - 1].end = nil
            }
        }

        self.link = link
        self.segments = normalized
    }

    /// Filters, sorts, and deduplicates `elements` based on the ``Segment``
    /// extracted from each element by `extractSegment`.
    ///
    /// 1. **Sort** — elements are ordered by ascending `segment.start`.
    /// 2. **Filter** — elements whose segment is invalid (zero or negative
    ///    length) are removed.
    /// 3. **Deduplicate** — when two elements share the same `segment.start`,
    ///    the first one wins and the second is discarded.
    ///
    /// - Returns: normalized elements in ascending `segment.start` order.
    static func normalizeSegments<T>(
        _ elements: [T],
        extracting extractSegment: (T) -> Segment
    ) -> [T] {
        elements
            .filter { extractSegment($0).isValid }
            .sorted { extractSegment($0).start < extractSegment($1).start }
            .reduce(into: []) { acc, element in
                // Deduplicate elements with the same segment start (keep first).
                if acc.last.map({ extractSegment($0).start }) != extractSegment(element).start {
                    acc.append(element)
                }
            }
    }

    // MARK: - Time Calculations

    /// Returns the playable duration of the segment at `index`.
    ///
    /// Returns `nil` if `index` is out of range or the last segment has no
    /// explicit `end` and `fileDuration` is not yet known.
    public func segmentDuration(at index: Int, fileDuration: TimeInterval?) -> TimeInterval? {
        guard segments.indices.contains(index) else {
            return nil
        }

        let segment = segments[index]
        if let end = segment.end {
            return end - segment.start
        } else if index < segments.count - 1 {
            return segments[index + 1].start - segment.start
        } else {
            return fileDuration.map { $0 - segment.start }
        }
    }

    /// Returns the sum of all segment durations (gaps between segments
    /// excluded), or `nil` if the duration cannot be determined.
    ///
    /// When there are no segments the clip covers the whole audio file, so
    /// `fileDuration` is returned directly (or `nil` if unknown).
    /// When the last segment has no explicit `end`, `fileDuration` is required
    /// to compute its contribution; `nil` is returned if it is unknown.
    public func duration(fileDuration: TimeInterval?) -> TimeInterval? {
        guard !segments.isEmpty else {
            return fileDuration
        }

        var total: TimeInterval = 0
        for i in segments.indices {
            guard let dur = segmentDuration(at: i, fileDuration: fileDuration) else {
                return nil
            }
            total += dur
        }
        return total
    }

    /// Returns an array where `result[i]` is the total playback time elapsed
    /// before segment `i` begins, with `result[0] == 0`.
    ///
    /// Intermediate nil-end segment durations are resolved from the next
    /// segment's start, so no `fileDuration` is needed. The last segment's own
    /// duration is never required for a prefix sum (nothing follows it), so the
    /// result is always fully deterministic at clip-load time.
    func computeCumulativeElapsed() -> [TimeInterval] {
        var result: [TimeInterval] = []
        result.reserveCapacity(segments.count)
        var elapsed: TimeInterval = 0
        for i in segments.indices {
            result.append(elapsed)
            if let dur = segmentDuration(at: i, fileDuration: nil) {
                elapsed += dur
            }
        }
        return result
    }
}
