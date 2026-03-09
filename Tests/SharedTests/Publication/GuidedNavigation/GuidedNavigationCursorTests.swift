//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

@MainActor
enum GuidedNavigationCursorTests {
    @MainActor struct Init {
        @Test func emptyReadingOrder() async {
            let cursor = makeCursor(readingOrder: [], gnds: [:])
            #expect(await cursor.next() == nil)
            #expect(await cursor.previous() == nil)
            #expect(!cursor.hasGuidedNavigation(for: "any.html"))
        }

        @Test func deduplicatesGNDHREFs() async {
            // Two reading order items mapped to the same GND.
            let doc = gnd(gno(audioRef: "a.mp3"))
            let cursor = makeCursor(
                readingOrder: ["chapter1.html", "chapter2.html"],
                gnds: ["chapter1.html": ("gnd.json", doc), "chapter2.html": ("gnd.json", doc)]
            )
            // Should only traverse the GND once — two calls to next() exhaust it.
            let n1 = await cursor.next()
            let n2 = await cursor.next()
            #expect(n1 != nil)
            #expect(n2 == nil)
        }
    }

    @MainActor struct HasGuidedNavigation {
        @Test func returnsTrueForCoveredHREF() {
            let cursor = makeCursor(
                readingOrder: ["chapter.html"],
                gnds: ["chapter.html": ("gnd.json", gnd(gno(audioRef: "a.mp3")))]
            )
            #expect(cursor.hasGuidedNavigation(for: "chapter.html"))
        }

        @Test func returnsFalseForUncoveredHREF() {
            let cursor = makeCursor(
                readingOrder: ["chapter.html", "other.html"],
                gnds: ["chapter.html": ("gnd.json", gnd(gno(audioRef: "a.mp3")))]
            )
            #expect(!cursor.hasGuidedNavigation(for: "other.html"))
        }
    }

    @MainActor struct Next {
        @Test func singleGND() async {
            let b = gno(audioRef: "b.mp3")
            let a = gno(audioRef: "a.mp3", children: [b])
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a))]
            )
            let nodeA = await cursor.next()
            #expect(nodeA?.object == a)
            #expect(nodeA?.ancestors == [])

            let nodeB = await cursor.next()
            #expect(nodeB?.object == b)
            #expect(nodeB?.ancestors == [a])

            #expect(await cursor.next() == nil)
        }

        @Test func crossesGNDBoundary() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            #expect(await cursor.next()?.object == a)
            #expect(await cursor.next()?.object == b)
            #expect(await cursor.next() == nil)
        }

        @Test func skipsReadingOrderItemsWithNoGND() async {
            let a = gno(audioRef: "a.mp3")
            let cursor = makeCursor(
                readingOrder: ["no-gnd.html", "ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a))]
            )
            #expect(await cursor.next()?.object == a)
            #expect(await cursor.next() == nil)
        }

        @Test func skipsFailingGNDFetch() async {
            let a = gno(audioRef: "a.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "x.mp3"))),
                    "ch2.html": ("gnd2.json", gnd(a)),
                ],
                failing: ["gnd1.json"]
            )
            #expect(await cursor.next()?.object == a)
            #expect(await cursor.next() == nil)
        }

        @Test func skipsEmptyGNDDocument() async {
            let a = gno(audioRef: "a.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd()),
                    "ch2.html": ("gnd2.json", gnd(a)),
                ]
            )
            #expect(await cursor.next()?.object == a)
            #expect(await cursor.next() == nil)
        }

        @Test func returnsNilAtEnd() async {
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(gno(audioRef: "a.mp3")))]
            )
            _ = await cursor.next()
            #expect(await cursor.next() == nil)
            #expect(await cursor.next() == nil)
        }
    }

    @MainActor struct Previous {
        @Test func returnsNilAtStart() async {
            let a = gno(audioRef: "a.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a))]
            )
            #expect(await cursor.previous() == nil)
            #expect(await cursor.previous() == nil)
            // State is intact: next() still works.
            #expect(await cursor.next()?.object == a)
        }

        @Test func reversesWithinSingleGND() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a, b))]
            )
            _ = await cursor.next()
            _ = await cursor.next()
            #expect(await cursor.previous()?.object == b)
            #expect(await cursor.previous()?.object == a)
            #expect(await cursor.previous() == nil)
        }

        @Test func crossesGNDBoundaryBackward() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            _ = await cursor.next()
            _ = await cursor.next()
            #expect(await cursor.previous()?.object == b)
            #expect(await cursor.previous()?.object == a)
            #expect(await cursor.previous() == nil)
        }

        @Test func fromExhaustedState() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            _ = await cursor.next() // a
            _ = await cursor.next() // b
            _ = await cursor.next() // nil — gnIndex advances past end
            // previous() from after-end must start from the last GND.
            #expect(await cursor.previous()?.object == b)
            #expect(await cursor.previous()?.object == a)
            #expect(await cursor.previous() == nil)
        }

        @Test func nextThenPreviousReturnsSameNode() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            _ = await cursor.next() // a
            let forward = await cursor.next() // b — crosses GND boundary
            let backward = await cursor.previous() // should also be b
            #expect(forward?.object == b)
            #expect(backward?.object == b)
        }

        @Test func skipsFailingGNDFetchBackward() async {
            // Three GNDs: gnd1 (a), gnd2 (fails), gnd3 (c).
            // Navigating backward from gnd3 must skip gnd2 and land on a.
            let a = gno(audioRef: "a.mp3")
            let c = gno(audioRef: "c.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html", "ch3.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "x.mp3"))),
                    "ch3.html": ("gnd3.json", gnd(c)),
                ],
                failing: ["gnd2.json"]
            )
            _ = await cursor.next() // a
            _ = await cursor.next() // c (gnd2 silently skipped)
            #expect(await cursor.previous()?.object == c)
            #expect(await cursor.previous()?.object == a) // gnd2 silently skipped backward
            #expect(await cursor.previous() == nil)
        }

        @Test func landsOnLastItemOfPreviousGND() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let c = gno(audioRef: "c.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a, b)),
                    "ch2.html": ("gnd2.json", gnd(c)),
                ]
            )
            _ = await cursor.next() // a
            _ = await cursor.next() // b
            _ = await cursor.next() // c
            #expect(await cursor.previous()?.object == c)
            #expect(await cursor.previous()?.object == b)
            #expect(await cursor.previous()?.object == a)
            #expect(await cursor.previous() == nil)
        }
    }

    @MainActor struct SeekIndexPath {
        @Test func emptyIndexPathReturnsFalse() async {
            let a = gno(audioRef: "a.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a))]
            )
            #expect(await !cursor.seek(to: []))
            #expect(await !cursor.seek(to: [0])) // only gnd index, no tree path
        }

        @Test func seekFirstNodeFirstGND() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a, b))]
            )
            #expect(await cursor.seek(to: [0, 0]))
            #expect(await cursor.next()?.object == a)
        }

        @Test func seekFirstNodeSecondGND() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            #expect(await cursor.seek(to: [1, 0]))
            #expect(await cursor.next()?.object == b)
        }

        @Test func seekNestedNode() async {
            // Tree: A → [B, C]
            let b = gno(audioRef: "b.mp3")
            let c = gno(audioRef: "c.mp3")
            let a = gno(audioRef: "a.mp3", children: [b, c])
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a))]
            )
            #expect(await cursor.seek(to: [0, 0, 1]))
            let node = await cursor.next()
            #expect(node?.object == c)
            #expect(node?.ancestors == [a])
        }

        @Test func outOfBoundsGNDIndexReturnsFalse() async {
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(gno(audioRef: "a.mp3")))]
            )
            #expect(await !cursor.seek(to: [5, 0]))
        }

        @Test func outOfBoundsTreeIndexReturnsFalse() async {
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(gno(audioRef: "a.mp3")))]
            )
            #expect(await !cursor.seek(to: [0, 99]))
        }

        @Test func outOfBoundsLeavesStateUnchanged() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a, b))]
            )
            _ = await cursor.next() // a
            #expect(await !cursor.seek(to: [0, 99]))
            // State unchanged: next() returns b, not a restart.
            #expect(await cursor.next()?.object == b)
        }

        @Test func gndFetchFailureReturnsFalse() async {
            let a = gno(audioRef: "a.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a))],
                failing: ["gnd.json"]
            )
            #expect(await !cursor.seek(to: [0, 0]))
        }

        @Test func seekThenPreviousCrossesGNDBoundary() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            // Seek into gnd2, then navigate backward into gnd1.
            #expect(await cursor.seek(to: [1, 0]))
            #expect(await cursor.next()?.object == b)
            #expect(await cursor.previous()?.object == b)
            #expect(await cursor.previous()?.object == a)
            #expect(await cursor.previous() == nil)
        }

        @Test func nodeIndexPathPrependsGNDIndex() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            #expect(await cursor.seek(to: [1, 0]))
            let node = await cursor.next()
            #expect(node?.indexPath == [1, 0])
        }
    }

    @MainActor struct Seek {
        @Test func unrefinedWebReferenceFirstGND() async {
            let a = gno(audioRef: "a.mp3", textRef: "ch.html#p1")
            let b = gno(audioRef: "b.mp3", textRef: "ch.html#p2")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a, b))]
            )
            #expect(await cursor.seek(to: WebReference(href: "ch.html")))
            #expect(await cursor.next()?.object == a)
        }

        @Test func unrefinedWebReferenceSecondGND() async {
            let a = gno(audioRef: "a.mp3", textRef: "ch1.html#p1")
            let b = gno(audioRef: "b.mp3", textRef: "ch2.html#p1")
            let c = gno(audioRef: "c.mp3", textRef: "ch2.html#p2")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b, c)),
                ]
            )
            #expect(await cursor.seek(to: WebReference(href: "ch2.html")))
            #expect(await cursor.next()?.object == b)
        }

        @Test func refinedWebReference() async {
            let a = gno(audioRef: "a.mp3", textRef: "ch.html#para1")
            let b = gno(audioRef: "b.mp3", textRef: "ch.html#para2")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a, b))]
            )
            #expect(await cursor.seek(to: WebReference(href: "ch.html", cssSelector: CSSSelector(id: "para2"))))
            #expect(await cursor.next()?.object == b)
        }

        @Test func refinedWebReferenceNotFoundReturnsFalse() async {
            let a = gno(audioRef: "a.mp3", textRef: "ch.html#para1")
            let b = gno(audioRef: "b.mp3", textRef: "ch.html#para2")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a, b))]
            )
            _ = await cursor.next() // position on a
            // Seek to a non-existent selector — cursor state must be unchanged.
            #expect(await !(cursor.seek(to: WebReference(href: "ch.html", cssSelector: CSSSelector(id: "missing")))))
            // Cursor is still positioned before b, not reset to beginning.
            #expect(await cursor.next()?.object == b)
        }

        @Test func unknownHREFReturnsFalse() async {
            let a = gno(audioRef: "a.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a))]
            )
            // Seek to unknown HREF — cursor state must be unchanged.
            #expect(await !(cursor.seek(to: WebReference(href: "unknown.html"))))
            // State unchanged: cursor is still at start, next() returns a.
            #expect(await cursor.next()?.object == a)
        }

        @Test func seekViaSecondHREFInDeduplicatedGND() async {
            // ch1 and ch2 both map to the same GND. Seeking via ch2 must
            // succeed and resolve within the shared document.
            let a = gno(audioRef: "a.mp3", textRef: "ch1.html#p1")
            let b = gno(audioRef: "b.mp3", textRef: "ch2.html#p1")
            let doc = gnd(a, b)
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd.json", doc),
                    "ch2.html": ("gnd.json", doc),
                ]
            )
            #expect(await cursor.seek(to: WebReference(href: "ch2.html")))
            #expect(await cursor.next()?.object == b)
        }

        @Test func gndFetchFailureReturnsFalse() async {
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(gno(audioRef: "a.mp3", textRef: "ch.html#p1")))],
                failing: ["gnd.json"]
            )
            let ref = WebReference(href: "ch.html")
            #expect(await !(cursor.seek(to: ref)))
        }

        @Test func seekThenPreviousCrossesGNDBoundary() async {
            let a = gno(audioRef: "a.mp3", textRef: "ch1.html#p1")
            let b = gno(audioRef: "b.mp3", textRef: "ch2.html#p1")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            // Seek into gnd2, then navigate backward into gnd1.
            #expect(await cursor.seek(to: WebReference(href: "ch2.html")))
            #expect(await cursor.next()?.object == b)
            #expect(await cursor.previous()?.object == b)
            #expect(await cursor.previous()?.object == a)
            #expect(await cursor.previous() == nil)
        }

        @Test func unrefinedAudioReferenceSeek() async {
            // An unrefined AudioReference (no temporal selector) matches the
            // first node whose audio href matches.
            let a = gno(audioRef: "audio.mp3#t=0,1")
            let b = gno(audioRef: "audio.mp3#t=1,2")
            let cursor = makeCursor(
                readingOrder: ["audio.mp3"],
                gnds: ["audio.mp3": ("gnd.json", gnd(a, b))]
            )
            let ref = AudioReference(href: "audio.mp3")
            #expect(await cursor.seek(to: ref))
            #expect(await cursor.next()?.object == a)
        }

        @Test func audioReferenceSeek() async {
            // When the reading order item is the audio file itself (pure
            // audiobook), seeking with an AudioReference finds the correct
            // node.
            let a = gno(audioRef: "audio.mp3#t=0,1")
            let b = gno(audioRef: "audio.mp3#t=1,2")
            let cursor = makeCursor(
                readingOrder: ["audio.mp3"],
                gnds: ["audio.mp3": ("gnd.json", gnd(a, b))]
            )
            let ref = AudioReference(
                href: "audio.mp3",
                temporal: .clip(TemporalClip(start: 1, end: 2))
            )
            #expect(await cursor.seek(to: ref))
            #expect(await cursor.next()?.object == b)
        }
    }

    @MainActor struct SkipToNextResource {
        @Test func returnsFalseForEmptyCursor() {
            let cursor = makeCursor(readingOrder: [], gnds: [:])
            #expect(!cursor.canSkipToNextResource)
        }

        @Test func returnsFalseInSingleResourceGND() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.html#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.html#p2")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a, b))]
            )
            // At initial state.
            #expect(!cursor.canSkipToNextResource)
            // After first node — still the only GND.
            _ = await cursor.next()
            #expect(!cursor.canSkipToNextResource)
            // After second node — still the only GND.
            _ = await cursor.next()
            #expect(!cursor.canSkipToNextResource)
        }

        // This is not supported because too costly to compute. We simplify
        // by only checking whether there is a GND after the current one.
//        @Test func returnsFalseWhenBothGNDsReferenceTheSameResource() async {
//            // Two distinct GNDs, but every node references the same reading
//            // order resource (ch1.html); there is no "next different resource"
//            // to skip to.
//            let cursor = makeCursor(
//                readingOrder: ["ch1.html", "ch2.html"],
//                gnds: [
//                    "ch1.html": ("gnd1.json", gnd(
//                        gno(audioRef: "audio.mp3#t=0,1", textRef: "ch1.html#p1"),
//                        gno(audioRef: "audio.mp3#t=1,2", textRef: "ch1.html#p2")
//                    )),
//                    "ch2.html": ("gnd2.json", gnd(
//                        gno(audioRef: "audio.mp3#t=2,3", textRef: "ch1.html#p3")
//                    )),
//                ]
//            )
//            _ = await cursor.next()
//            #expect(!cursor.canSkipToNextResource)
//        }

        @Test func returnsFalseWhenExhausted() async {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1"))),
                ]
            )
            _ = await cursor.next() // a
            _ = await cursor.next() // b
            _ = await cursor.next() // nil — cursor past the end
            #expect(!cursor.canSkipToNextResource)
        }

        // This is not supported because too costly to compute. We simplify
        // by only checking whether there is a GND after the current one.
//        @Test func singleGNDSpanningTwoResources() async {
//            // One GND covers two reading order resources.
//            let a1 = gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1")
//            let a2 = gno(audioRef: "audio1.mp3#t=1,2", textRef: "ch1.html#p2")
//            let b1 = gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1")
//            let b2 = gno(audioRef: "audio2.mp3#t=1,2", textRef: "ch2.html#p2")
//            let doc = gnd(a1, a2, b1, b2)
//            let cursor = makeCursor(
//                readingOrder: ["ch1.html", "ch2.html"],
//                gnds: [
//                    "ch1.html": ("gnd.json", doc),
//                    "ch2.html": ("gnd.json", doc),
//                ]
//            )
//            _ = await cursor.next() // a1 — references ch1.html
//            #expect(cursor.canSkipToNextResource)
//            _ = await cursor.next() // a2 — references ch1.html
//            #expect(cursor.canSkipToNextResource)
//            _ = await cursor.next() // b1 — references ch2.html, no further resource
//            #expect(!cursor.canSkipToNextResource)
//        }

        @Test func multipleGNDsEachWithDistinctResource() async {
            let a1 = gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1")
            let a2 = gno(audioRef: "audio1.mp3#t=1,2", textRef: "ch1.html#p2")
            let b1 = gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1")
            let b2 = gno(audioRef: "audio2.mp3#t=1,2", textRef: "ch2.html#p2")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a1, a2)),
                    "ch2.html": ("gnd2.json", gnd(b1, b2)),
                ]
            )
            _ = await cursor.next() // a1 — in gnd1, not the last GND
            #expect(cursor.canSkipToNextResource)
            _ = await cursor.next() // a2 — in gnd1, not the last GND
            #expect(cursor.canSkipToNextResource)
            _ = await cursor.next() // b1 — in gnd2, the last GND
            #expect(!cursor.canSkipToNextResource)
        }

        @Test func skipsToFirstNodeOfNextResourceAcrossGNDs() async {
            let a1 = gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1")
            let a2 = gno(audioRef: "audio1.mp3#t=1,2", textRef: "ch1.html#p2")
            let b1 = gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1")
            let b2 = gno(audioRef: "audio2.mp3#t=1,2", textRef: "ch2.html#p2")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a1, a2)),
                    "ch2.html": ("gnd2.json", gnd(b1, b2)),
                ]
            )
            _ = await cursor.next() // a1
            await cursor.skipToNextResource()
            // Must land on b1, not a2.
            #expect(await cursor.next()?.object == b1)
        }

        @Test func skipsToFirstNodeOfNextResourceInSingleGND() async {
            // Same GND covers both resources; skip must land on the first node
            // of ch2.html, bypassing the second node of ch1.html.
            let a1 = gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1")
            let a2 = gno(audioRef: "audio1.mp3#t=1,2", textRef: "ch1.html#p2")
            let b = gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1")
            let doc = gnd(a1, a2, b)
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd.json", doc),
                    "ch2.html": ("gnd.json", doc),
                ]
            )
            _ = await cursor.next() // a1
            await cursor.skipToNextResource()
            #expect(await cursor.next()?.object == b)
        }
    }

    @MainActor struct SkipToPreviousResource {
        @Test func returnsFalseForEmptyCursor() {
            let cursor = makeCursor(readingOrder: [], gnds: [:])
            #expect(!cursor.canSkipToPreviousResource)
        }

        @Test func returnsFalseInSingleResourceGND() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.html#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.html#p2")
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(a, b))]
            )
            // At initial state.
            #expect(!cursor.canSkipToPreviousResource)
            // After first node — still the first (and only) GND.
            _ = await cursor.next()
            #expect(!cursor.canSkipToPreviousResource)
            // After second node — still the first (and only) GND.
            _ = await cursor.next()
            #expect(!cursor.canSkipToPreviousResource)
        }

        @Test func canSkipToPreviousResourceAfterSeekToSecondGND() async {
            // seek() positions before the node (lastNode is nil until next() is
            // called). canSkipToPreviousResource requires lastNode to be set.
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            #expect(await cursor.seek(to: [1, 0]))
            #expect(!cursor.canSkipToPreviousResource) // lastNode is nil before next()
            _ = await cursor.next() // b — now lastNode is set, gndIndex == 1
            #expect(cursor.canSkipToPreviousResource)
        }

        // This is not supported because too costly to compute. We simplify
        // by only checking whether there is a GND before the current one.
//        @Test func returnsFalseWhenBothGNDsReferenceTheSameResource() async {
//            let cursor = makeCursor(
//                readingOrder: ["ch1.html", "ch2.html"],
//                gnds: [
//                    "ch1.html": ("gnd1.json", gnd(
//                        gno(audioRef: "audio.mp3#t=0,1", textRef: "ch1.html#p1"),
//                        gno(audioRef: "audio.mp3#t=1,2", textRef: "ch1.html#p2")
//                    )),
//                    "ch2.html": ("gnd2.json", gnd(
//                        gno(audioRef: "audio.mp3#t=2,3", textRef: "ch1.html#p3")
//                    )),
//                ]
//            )
//            _ = await cursor.next() // gnd1, node 1
//            _ = await cursor.next() // gnd1, node 2
//            _ = await cursor.next() // gnd2, node — still ch1.html
//            // At the end; no different resource ever appeared before us.
//            #expect(!cursor.canSkipToPreviousResource)
//        }

        @Test func returnsFalseWhenExhausted() async {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1"))),
                ]
            )
            _ = await cursor.next() // a
            _ = await cursor.next() // b
            _ = await cursor.previous() // b
            _ = await cursor.previous() // a
            _ = await cursor.previous() // nil — cursor before the beginning
            #expect(!cursor.canSkipToPreviousResource)
        }

        // This is not supported because too costly to compute. We simplify
        // by only checking whether there is a GND before the current one.
//        @Test func singleGNDSpanningTwoResources() async {
//            let a = gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1")
//            let b = gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1")
//            let doc = gnd(a, b)
//            let cursor = makeCursor(
//                readingOrder: ["ch1.html", "ch2.html"],
//                gnds: [
//                    "ch1.html": ("gnd.json", doc),
//                    "ch2.html": ("gnd.json", doc),
//                ]
//            )
//            _ = await cursor.next() // a — references ch1.html, nothing different before
//            #expect(!cursor.canSkipToPreviousResource)
//            _ = await cursor.next() // b — references ch2.html, ch1.html is before
//            #expect(cursor.canSkipToPreviousResource)
//        }

        @Test func multipleGNDsEachWithDistinctResource() async {
            let a = gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1")
            let b = gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            _ = await cursor.next() // a — in gnd1, the first GND
            #expect(!cursor.canSkipToPreviousResource)
            _ = await cursor.next() // b — in gnd2, gnd1 is before
            #expect(cursor.canSkipToPreviousResource)
        }

        @Test func skipsToFirstNodeOfPreviousResourceAcrossGNDs() async {
            let a1 = gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1")
            let a2 = gno(audioRef: "audio1.mp3#t=1,2", textRef: "ch1.html#p2")
            let b1 = gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1")
            let b2 = gno(audioRef: "audio2.mp3#t=1,2", textRef: "ch2.html#p2")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a1, a2)),
                    "ch2.html": ("gnd2.json", gnd(b1, b2)),
                ]
            )
            _ = await cursor.next() // a1
            _ = await cursor.next() // a2
            _ = await cursor.next() // b1
            _ = await cursor.next() // b2 — positioned on b2
            await cursor.skipToPreviousResource()
            // Must land on a1, not b1 or a2.
            #expect(await cursor.next()?.object == a1)
        }

        @Test func skipsToFirstNodeOfPreviousResourceInSingleGND() async {
            // Same GND covers both resources; skip back must land on the first
            // node of ch1.html, not on b1 (second node of ch2.html).
            let a = gno(audioRef: "audio1.mp3#t=0,1", textRef: "ch1.html#p1")
            let b1 = gno(audioRef: "audio2.mp3#t=0,1", textRef: "ch2.html#p1")
            let b2 = gno(audioRef: "audio2.mp3#t=1,2", textRef: "ch2.html#p2")
            let doc = gnd(a, b1, b2)
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd.json", doc),
                    "ch2.html": ("gnd.json", doc),
                ]
            )
            _ = await cursor.next() // a
            _ = await cursor.next() // b1
            _ = await cursor.next() // b2 — positioned on b2
            await cursor.skipToPreviousResource()
            #expect(await cursor.next()?.object == a)
        }
    }
}

// MARK: - Helpers

private struct MockProvider: GuidedNavigationDocumentProvider {
    /// gndHREF string → document
    let gnds: [String: (href: AnyURL, doc: GuidedNavigationDocument)]
    /// roHREF string → gndHREF string
    let roMap: [String: String]
    /// gndHREF strings that should throw on fetch
    let failing: Set<String>

    func guidedNavigationDocumentHREF(for readingOrderHREF: any URLConvertible) -> AnyURL? {
        let key = readingOrderHREF.anyURL.removingFragment().string
        guard let gndKey = roMap[key] else { return nil }
        return gnds[gndKey]?.href
    }

    func guidedNavigationDocument(at href: any URLConvertible) async throws(ReadError) -> GuidedNavigationDocument? {
        let key = href.anyURL.removingFragment().string
        if failing.contains(key) {
            throw ReadError.decoding(DebugError("Failure"))
        }
        return gnds[key]?.doc
    }
}

/// Builds a `GuidedNavigationCursor` from simplified test parameters.
///
/// - Parameters:
///   - readingOrder: HREF strings for the reading order links.
///   - gnds: Maps reading-order HREF string → (gndHREF string, document).
///   - failing: Set of GND HREF strings that should fail on fetch.
@MainActor
private func makeCursor(
    readingOrder: [String],
    gnds: [String: (String, GuidedNavigationDocument)],
    failing: Set<String> = []
) -> GuidedNavigationCursor {
    var gndMap: [String: (href: AnyURL, doc: GuidedNavigationDocument)] = [:]
    var roMap: [String: String] = [:]

    for (roHREF, (gndHREF, doc)) in gnds {
        gndMap[gndHREF] = (AnyURL(string: gndHREF)!, doc)
        roMap[roHREF] = gndHREF
    }

    let provider = MockProvider(gnds: gndMap, roMap: roMap, failing: failing)
    let links = readingOrder.map { AnyURL(string: $0)! }
    return GuidedNavigationCursor(readingOrder: links, provider: provider)
}

private func gno(
    audioRef: String? = nil,
    imgRef: String? = nil,
    textRef: String? = nil,
    roles: [ContentRole] = [],
    children: [GuidedNavigationObject] = []
) -> GuidedNavigationObject {
    guard let obj = GuidedNavigationObject(
        refs: GuidedNavigationObject.Refs(
            text: textRef.flatMap { AnyURL(string: $0).map { WebReference(href: $0) } },
            image: imgRef.flatMap { AnyURL(string: $0).map { ImageReference(href: $0) } },
            audio: audioRef.flatMap { AnyURL(string: $0).map { AudioReference(href: $0) } }
        ),
        roles: roles,
        children: children
    ) else {
        preconditionFailure("Invalid GuidedNavigationObject in test")
    }
    return obj
}

private func gnd(_ objects: GuidedNavigationObject...) -> GuidedNavigationDocument {
    GuidedNavigationDocument(guided: objects)
}
