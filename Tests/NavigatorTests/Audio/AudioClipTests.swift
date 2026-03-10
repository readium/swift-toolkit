//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum AudioClipTests {
    static let link = Link(href: "audio.mp3")

    static func seg(_ start: TimeInterval, _ end: TimeInterval? = nil) -> AudioClip.Segment {
        AudioClip.Segment(start: start, end: end)
    }

    struct NormalizingInit {
        @Test("already sorted segments are unchanged")
        func alreadySorted() {
            let clip = AudioClip(link: link, segments: [
                seg(0, 1),
                seg(1, 2),
                seg(2, 3),
            ])
            #expect(clip.segments.map(\.start) == [0, 1, 2])
            #expect(clip.segments.map(\.end) == [1, 2, 3])
        }

        @Test("unsorted segments are sorted by start")
        func sortsSegments() {
            let clip = AudioClip(link: link, segments: [
                seg(2, 3),
                seg(0, 1),
                seg(1, 2),
            ])
            #expect(clip.segments.map(\.start) == [0, 1, 2])
        }

        @Test("duplicate start values are deduplicated, first wins")
        func deduplicatesByStart() {
            let first = AudioClip.Segment(id: UUID(), start: 1, end: 2)
            let duplicate = AudioClip.Segment(id: UUID(), start: 1, end: 5)
            let clip = AudioClip(link: link, segments: [first, seg(0, 1), duplicate])
            #expect(clip.segments.count == 2)
            #expect(clip.segments[1].id == first.id)
        }

        @Test("overlapping segments have earlier end cleared")
        func overlappingSegmentsClearsEnd() {
            let clip = AudioClip(link: link, segments: [
                seg(0, 5),
                seg(3, 6),
            ])
            #expect(clip.segments.count == 2)
            #expect(clip.segments[0].end == nil)
            #expect(clip.segments[1].start == 3)
            #expect(clip.segments[1].end == 6)
        }

        @Test("adjacent segments (end == next start) are not considered overlapping")
        func adjacentSegmentsNotOverlapping() {
            let clip = AudioClip(link: link, segments: [
                seg(0, 1),
                seg(1, 2),
            ])
            #expect(clip.segments[0].end == 1)
        }

        @Test("segments with nil end followed by later segment")
        func nilEndSegment() {
            let clip = AudioClip(link: link, segments: [
                seg(0, nil),
                seg(2, 3),
            ])
            #expect(clip.segments.count == 2)
            #expect(clip.segments[0].end == nil)
        }

        @Test("segment with end before start is dropped")
        func endBeforeStartDropped() {
            let clip = AudioClip(link: link, segments: [seg(10, 5)])
            #expect(clip.segments.isEmpty)
        }

        @Test("zero-length segment (end == start) is dropped")
        func zeroLengthDropped() {
            let clip = AudioClip(link: link, segments: [seg(10, 10)])
            #expect(clip.segments.isEmpty)
        }

        @Test("empty segments list")
        func emptySegments() {
            let clip = AudioClip(link: link, segments: [])
            #expect(clip.segments.isEmpty)
        }

        @Test("combined: unsorted, duplicates, and overlaps")
        func combined() {
            let clip = AudioClip(link: link, segments: [
                seg(5, 10),
                seg(0, 8), // overlaps with seg starting at 5
                seg(5, 7), // duplicate start with the first seg(5,10)
                seg(12, 15),
            ])
            // After sort: (0,8), (5,10), (5,7), (12,15)
            // Dedup (5): keep first = (5,10)
            // After sort+dedup: (0,8), (5,10), (12,15)
            // (0,8) overlaps (5,10) => clear end of (0,8)
            #expect(clip.segments.map(\.start) == [0, 5, 12])
            #expect(clip.segments[0].end == nil)
            #expect(clip.segments[1].end == 10)
            #expect(clip.segments[2].end == 15)
        }
    }

    // MARK: - segmentDuration(at:fileDuration:)

    struct SegmentDuration {
        @Test("segment with explicit end")
        func explicitEnd() {
            let clip = AudioClip(link: link, segments: [seg(10, 20)])
            #expect(clip.segmentDuration(at: 0, fileDuration: 60) == 10)
        }

        @Test("intermediate segment with nil end uses next segment start")
        func intermediateNilEnd() {
            // Overlapping input produces a nil-end intermediate segment.
            let clip = AudioClip(link: link, segments: [seg(0, 15), seg(10, 20)])
            // After normalisation: (0, nil), (10, 20)
            #expect(clip.segments[0].end == nil)
            #expect(clip.segmentDuration(at: 0, fileDuration: 60) == 10) // 10 - 0
        }

        @Test("last segment with nil end uses fileDuration")
        func lastNilEndWithFileDuration() {
            let clip = AudioClip(link: link, segments: [seg(10, nil)])
            #expect(clip.segmentDuration(at: 0, fileDuration: 60) == 50) // 60 - 10
        }

        @Test("last segment with nil end and no fileDuration returns nil")
        func lastNilEndNoFileDuration() {
            let clip = AudioClip(link: link, segments: [seg(10, nil)])
            #expect(clip.segmentDuration(at: 0, fileDuration: nil) == nil)
        }

        @Test("out-of-range index returns nil")
        func outOfRangeIndex() {
            let clip = AudioClip(link: link, segments: [seg(0, 10)])
            #expect(clip.segmentDuration(at: 5, fileDuration: 60) == nil)
        }
    }

    // MARK: - duration(fileDuration:)

    struct Duration {
        @Test("single segment with explicit end")
        func singleExplicitEnd() {
            let clip = AudioClip(link: link, segments: [seg(5, 15)])
            #expect(clip.duration(fileDuration: 60) == 10)
        }

        @Test("multiple segments with gaps excluded")
        func multipleSegmentsGapsExcluded() {
            // Segments: 10-20 (10s), gap 20-35, 35-50 (15s) → total 25s
            let clip = AudioClip(link: link, segments: [seg(10, 20), seg(35, 50)])
            #expect(clip.duration(fileDuration: 60) == 25)
        }

        @Test("last segment with nil end uses fileDuration")
        func lastNilEnd() {
            // Segments: 0-10 (10s), 20-end; file is 60s → 10 + (60-20) = 50s
            let clip = AudioClip(link: link, segments: [seg(0, 10), seg(20, nil)])
            #expect(clip.duration(fileDuration: 60) == 50)
        }

        @Test("last segment with nil end and no fileDuration returns nil")
        func lastNilEndNoFileDuration() {
            let clip = AudioClip(link: link, segments: [seg(0, 10), seg(20, nil)])
            #expect(clip.duration(fileDuration: nil) == nil)
        }

        @Test("empty segments list returns fileDuration (whole file)")
        func emptySegmentsWithFileDuration() {
            let clip = AudioClip(link: link, segments: [])
            #expect(clip.duration(fileDuration: 60) == 60)
        }

        @Test("empty segments list with no fileDuration returns nil")
        func emptySegmentsNoFileDuration() {
            let clip = AudioClip(link: link, segments: [])
            #expect(clip.duration(fileDuration: nil) == nil)
        }

        @Test("intermediate nil-end segment (normalised overlap) is counted correctly")
        func intermediateNilEnd() {
            // Input: (0,15) and (10,20) → normalised to (0,nil),(10,20)
            // Segment 0 duration = 10-0 = 10; segment 1 duration = 20-10 = 10 → total 20
            let clip = AudioClip(link: link, segments: [seg(0, 15), seg(10, 20)])
            #expect(clip.duration(fileDuration: 60) == 20)
        }
    }

    // MARK: - computeCumulativeElapsed()

    struct CumulativeElapsed {
        @Test("empty segments returns empty array")
        func emptySegments() {
            let clip = AudioClip(link: link, segments: [])
            #expect(clip.computeCumulativeElapsed() == [])
        }

        @Test("single segment with explicit end")
        func singleExplicitEnd() {
            let clip = AudioClip(link: link, segments: [seg(10, 20)])
            #expect(clip.computeCumulativeElapsed() == [0])
        }

        @Test("multiple segments with gaps: prefix sums exclude gaps")
        func multipleWithGaps() {
            // Segments: 10-20 (10s), gap, 35-50 (15s)
            let clip = AudioClip(link: link, segments: [seg(10, 20), seg(35, 50)])
            #expect(clip.computeCumulativeElapsed() == [0, 10])
        }

        @Test("intermediate nil-end segment (overlap-resolved) uses next segment start")
        func intermediateNilEnd() {
            // Input: (0,15) and (10,20) → normalised to (0,nil),(10,20)
            // Segment 0 duration = 10-0 = 10; prefix before seg 1 = 10
            let clip = AudioClip(link: link, segments: [seg(0, 15), seg(10, 20)])
            #expect(clip.computeCumulativeElapsed() == [0, 10])
        }

        @Test("last segment with nil end: prefix sums still fully computed")
        func lastNilEnd() {
            // Segment 0: 10-20 (10s); segment 1: 30-nil (duration unknown without fileDuration)
            // Prefix before seg 0 = 0, before seg 1 = 10; last segment's own duration not needed.
            let clip = AudioClip(link: link, segments: [seg(10, 20), seg(30, nil)])
            #expect(clip.computeCumulativeElapsed() == [0, 10])
        }
    }
}
