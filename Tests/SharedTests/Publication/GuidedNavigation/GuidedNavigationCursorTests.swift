//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum GuidedNavigationCursorTests {
    struct Init {
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

    struct HasGuidedNavigation {
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

    struct Next {
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

    struct Previous {
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

    struct Seek {
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
            let cursor = makeCursor(
                readingOrder: ["ch.html"],
                gnds: ["ch.html": ("gnd.json", gnd(gno(audioRef: "a.mp3")))]
            )
            #expect(await !(cursor.seek(to: WebReference(href: "unknown.html"))))
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

    struct SkipToNextResource {
        @Test func canSkipIsFalseAtStart() {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "a.mp3"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "b.mp3"))),
                ]
            )
            #expect(!cursor.canSkipToNextResource)
        }

        @Test func canSkipIsTrueOnFirstOfTwo() async {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "a.mp3"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "b.mp3"))),
                ]
            )
            _ = await cursor.next()
            #expect(cursor.canSkipToNextResource)
        }

        @Test func canSkipIsFalseOnLastGND() async {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "a.mp3"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "b.mp3"))),
                ]
            )
            _ = await cursor.next()
            _ = await cursor.next()
            #expect(!cursor.canSkipToNextResource)
        }

        @Test func canSkipIsFalseWhenExhausted() async {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "a.mp3"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "b.mp3"))),
                ]
            )
            _ = await cursor.next()
            _ = await cursor.next()
            _ = await cursor.next() // exhaust
            #expect(!cursor.canSkipToNextResource)
        }

        @Test func skipPositionsBeforeFirstNodeOfNextGND() async {
            let a = gno(audioRef: "a.mp3")
            let b = gno(audioRef: "b.mp3")
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(a)),
                    "ch2.html": ("gnd2.json", gnd(b)),
                ]
            )
            _ = await cursor.next() // positions on first GND
            await cursor.skipToNextResource()
            #expect(await cursor.next()?.object == b)
        }
    }

    struct SkipToPreviousResource {
        @Test func canSkipIsFalseAtStartAndOnFirstGND() async {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "a.mp3"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "b.mp3"))),
                ]
            )
            #expect(!cursor.canSkipToPreviousResource)
            _ = await cursor.next()
            #expect(!cursor.canSkipToPreviousResource)
        }

        @Test func canSkipIsTrueOnSecondGND() async {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "a.mp3"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "b.mp3"))),
                ]
            )
            _ = await cursor.next()
            _ = await cursor.next()
            #expect(cursor.canSkipToPreviousResource)
        }

        @Test func canSkipToPreviousResourceAfterExhausting() async {
            let cursor = makeCursor(
                readingOrder: ["ch1.html", "ch2.html"],
                gnds: [
                    "ch1.html": ("gnd1.json", gnd(gno(audioRef: "a.mp3"))),
                    "ch2.html": ("gnd2.json", gnd(gno(audioRef: "b.mp3"))),
                ]
            )
            _ = await cursor.next()
            _ = await cursor.next()
            _ = await cursor.next() // exhaust
            #expect(cursor.canSkipToPreviousResource)
        }

        @Test func skipPositionsBeforeFirstNodeOfPreviousGND() async {
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
    let links = readingOrder.map { Link(href: $0) }
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
