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
}
