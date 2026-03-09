//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

enum GuidedNavigationDocumentCursorTests {
    // MARK: - next()

    struct Next {
        @Test func emptyDocument() {
            let cursor = GuidedNavigationDocumentCursor(document: gnd())
            #expect(cursor.next() == nil)
        }

        @Test func singleNode() {
            let node = gno(audio: "a.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(node))
            #expect(cursor.next()?.object == node)
            #expect(cursor.next() == nil)
        }

        @Test func flatList() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))
            #expect(cursor.next()?.object == a)
            #expect(cursor.next()?.object == b)
            #expect(cursor.next()?.object == c)
            #expect(cursor.next() == nil)
        }

        @Test func nestedTree() {
            // Tree:  [A → [B → [D, E]], C]
            // DFS pre-order: A, B, D, E, C
            let d = gno(audio: "d.mp3")
            let e = gno(audio: "e.mp3")
            let b = gno(audio: "b.mp3", children: [d, e])
            let a = gno(audio: "a.mp3", children: [b])
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, c))

            let nodeA = cursor.next()
            #expect(nodeA?.object == a)
            #expect(nodeA?.ancestors == [])

            let nodeB = cursor.next()
            #expect(nodeB?.object == b)
            #expect(nodeB?.ancestors == [a])

            let nodeD = cursor.next()
            #expect(nodeD?.object == d)
            #expect(nodeD?.ancestors == [a, b])

            let nodeE = cursor.next()
            #expect(nodeE?.object == e)
            #expect(nodeE?.ancestors == [a, b])

            let nodeC = cursor.next()
            #expect(nodeC?.object == c)
            #expect(nodeC?.ancestors == [])

            #expect(cursor.next() == nil)
        }

        @Test func returnsNilAtEnd() {
            let node = gno(audio: "a.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(node))
            _ = cursor.next()
            // Multiple calls at end are idempotent.
            #expect(cursor.next() == nil)
            #expect(cursor.next() == nil)
        }
    }

    // MARK: - previous()

    struct Previous {
        @Test func atStartReturnsNil() {
            let cursor = GuidedNavigationDocumentCursor(document: gnd(gno(audio: "a.mp3")))
            #expect(cursor.previous() == nil)
        }

        @Test func singleNode() {
            let node = gno(audio: "a.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(node))
            _ = cursor.next()
            #expect(cursor.previous()?.object == node)
            #expect(cursor.previous() == nil)
        }

        @Test func flatList() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))
            _ = cursor.next()
            _ = cursor.next()
            _ = cursor.next()
            #expect(cursor.previous()?.object == c)
            #expect(cursor.previous()?.object == b)
            #expect(cursor.previous()?.object == a)
            #expect(cursor.previous() == nil)
        }

        @Test func nestedTree() {
            // DFS pre-order: A, B, D, E, C
            // Reverse:       C, E, D, B, A
            let d = gno(audio: "d.mp3")
            let e = gno(audio: "e.mp3")
            let b = gno(audio: "b.mp3", children: [d, e])
            let a = gno(audio: "a.mp3", children: [b])
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, c))
            _ = cursor.next() // A
            _ = cursor.next() // B
            _ = cursor.next() // D
            _ = cursor.next() // E
            _ = cursor.next() // C

            let nodeC = cursor.previous()
            #expect(nodeC?.object == c)
            #expect(nodeC?.ancestors == [])

            let nodeE = cursor.previous()
            #expect(nodeE?.object == e)
            #expect(nodeE?.ancestors == [a, b])

            let nodeD = cursor.previous()
            #expect(nodeD?.object == d)
            #expect(nodeD?.ancestors == [a, b])

            let nodeB = cursor.previous()
            #expect(nodeB?.object == b)
            #expect(nodeB?.ancestors == [a])

            let nodeA = cursor.previous()
            #expect(nodeA?.object == a)
            #expect(nodeA?.ancestors == [])

            #expect(cursor.previous() == nil)
        }

        @Test func returnsNilAtStart() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))
            _ = cursor.next()
            _ = cursor.previous()
            // Multiple calls at start are idempotent.
            #expect(cursor.previous() == nil)
            #expect(cursor.previous() == nil)
            // State is intact: next() still works from beginning.
            #expect(cursor.next()?.object == a)
        }
    }

    // MARK: - Round-trip

    struct RoundTrip {
        @Test func forwardThenBackward() {
            // Full forward then full backward should yield items in reverse order.
            let d = gno(audio: "d.mp3")
            let e = gno(audio: "e.mp3")
            let b = gno(audio: "b.mp3", children: [d, e])
            let a = gno(audio: "a.mp3", children: [b])
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, c))

            var forward: [GuidedNavigationObject] = []
            while let node = cursor.next() {
                forward.append(node.object)
            }

            var backward: [GuidedNavigationObject] = []
            while let node = cursor.previous() {
                backward.append(node.object)
            }

            #expect(backward == forward.reversed())
        }
    }

    // MARK: - seekToEnd()

    struct SeekToEnd {
        @Test func emptyDocument() {
            let cursor = GuidedNavigationDocumentCursor(document: gnd())
            cursor.seekToEnd()
            #expect(cursor.previous() == nil)
        }

        @Test func singleNode() {
            let a = gno(audio: "a.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))
            cursor.seekToEnd()
            #expect(cursor.previous()?.object == a)
            #expect(cursor.previous() == nil)
        }

        @Test func flatList() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))
            cursor.seekToEnd()
            #expect(cursor.previous()?.object == c)
            #expect(cursor.previous()?.object == b)
            #expect(cursor.previous()?.object == a)
            #expect(cursor.previous() == nil)
        }

        @Test func nestedTree() {
            // Tree: A → [B → [D, E], C]
            // DFS pre-order: A, B, D, E, C — last node is C
            let d = gno(audio: "d.mp3")
            let e = gno(audio: "e.mp3")
            let b = gno(audio: "b.mp3", children: [d, e])
            let a = gno(audio: "a.mp3", children: [b])
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, c))
            cursor.seekToEnd()

            let nodeC = cursor.previous()
            #expect(nodeC?.object == c)
            #expect(nodeC?.ancestors == [])

            let nodeE = cursor.previous()
            #expect(nodeE?.object == e)
            #expect(nodeE?.ancestors == [a, b])
        }

        @Test func matchesReversedForwardTraversal() {
            // Full backward from end must match full forward in reverse.
            let d = gno(audio: "d.mp3")
            let e = gno(audio: "e.mp3")
            let b = gno(audio: "b.mp3", children: [d, e])
            let a = gno(audio: "a.mp3", children: [b])
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, c))

            var forward: [GuidedNavigationObject] = []
            while let node = cursor.next() {
                forward.append(node.object)
            }

            cursor.seekToEnd()

            var backward: [GuidedNavigationObject] = []
            while let node = cursor.previous() {
                backward.append(node.object)
            }

            #expect(backward == forward.reversed())
        }

        @Test func resetsStateAfterPartialNavigation() {
            // seekToEnd() mid-traversal should fully reposition to the end.
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))
            _ = cursor.next() // advance to A
            cursor.seekToEnd()
            #expect(cursor.previous()?.object == c)
        }
    }

    // MARK: - seek(to: IndexPath)

    struct SeekIndexPath {
        @Test func emptyIndexPathReturnsFalse() {
            let a = gno(audio: "a.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))
            #expect(!cursor.seek(to: []))
            // State unchanged: next() still returns the first node.
            #expect(cursor.next()?.object == a)
        }

        @Test func singleRootNode() {
            let a = gno(audio: "a.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))
            #expect(cursor.seek(to: [0]))
            #expect(cursor.next()?.object == a)
        }

        @Test func secondRootNode() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))
            #expect(cursor.seek(to: [1]))
            #expect(cursor.next()?.object == b)
        }

        @Test func nestedNode() {
            // Tree: A → [B, C]
            let b = gno(audio: "b.mp3")
            let c = gno(audio: "c.mp3")
            let a = gno(audio: "a.mp3", children: [b, c])
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))
            #expect(cursor.seek(to: [0, 0]))
            let node = cursor.next()
            #expect(node?.object == b)
            #expect(node?.ancestors == [a])
        }

        @Test func deepNestedNode() {
            // Tree: A → [B → [D, E]]
            let d = gno(audio: "d.mp3")
            let e = gno(audio: "e.mp3")
            let b = gno(audio: "b.mp3", children: [d, e])
            let a = gno(audio: "a.mp3", children: [b])
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))
            #expect(cursor.seek(to: [0, 0, 1]))
            let node = cursor.next()
            #expect(node?.object == e)
            #expect(node?.ancestors == [a, b])
        }

        @Test func outOfBoundsReturnsFalse() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))
            _ = cursor.next() // advance to a
            #expect(!cursor.seek(to: [5]))
            // State unchanged: next() returns b (we were on a).
            #expect(cursor.next()?.object == b)
        }

        @Test func outOfBoundsChildReturnsFalse() {
            let c1 = gno(audio: "c1.mp3")
            let c2 = gno(audio: "c2.mp3")
            let a = gno(audio: "a.mp3", children: [c1, c2])
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))
            #expect(!cursor.seek(to: [0, 3]))
        }

        @Test func seekFirstNodeThenPrevious() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))
            #expect(cursor.seek(to: [0]))
            #expect(cursor.previous() == nil)
            #expect(cursor.next()?.object == a)
        }

        @Test func seekThenContinueForward() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))
            #expect(cursor.seek(to: [1]))
            #expect(cursor.next()?.object == b)
            #expect(cursor.next()?.object == c)
            #expect(cursor.next() == nil)
        }

        @Test func seekThenPrevious() {
            let a = gno(audio: "a.mp3")
            let b = gno(audio: "b.mp3")
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))
            // Seek to b; previous() should return a then nil.
            #expect(cursor.seek(to: [1]))
            #expect(cursor.previous()?.object == a)
            #expect(cursor.previous() == nil)
        }

        @Test func indexPathReflectsTreePosition() {
            // Tree: A → [B → [D, E]], C
            let d = gno(audio: "d.mp3")
            let e = gno(audio: "e.mp3")
            let b = gno(audio: "b.mp3", children: [d, e])
            let a = gno(audio: "a.mp3", children: [b])
            let c = gno(audio: "c.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, c))
            #expect(cursor.seek(to: [0, 0, 1]))
            let node = cursor.next()
            #expect(node?.indexPath == [0, 0, 1])
        }
    }

    // MARK: - seek(to:)

    struct Seek {
        @Test func unrefinedAudioReference() throws {
            let href = try #require(AnyURL(string: "audio.mp3"))
            let a = gno(audio: "audio.mp3#t=0,1")
            let b = gno(audio: "audio.mp3#t=1,2")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))

            let ref = AudioReference(href: href)
            #expect(cursor.seek(to: ref))
            #expect(cursor.next()?.object == a)
        }

        @Test func webReference() throws {
            let href = try #require(AnyURL(string: "chapter.html"))
            let a = gno(audio: "a.mp3", textRef: "chapter.html#p1")
            let b = gno(audio: "b.mp3", textRef: "chapter.html#p2")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))

            let ref = WebReference(href: href)
            #expect(cursor.seek(to: ref))
            #expect(cursor.next()?.object == a)
        }

        @Test func imageReference() throws {
            let href = try #require(AnyURL(string: "page.jpg"))
            let a = gno(audio: "a.mp3", imgRef: "page.jpg#xywh=0,0,100,100")
            let b = gno(audio: "b.mp3", imgRef: "page.jpg#xywh=100,0,100,100")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))

            let ref = ImageReference(href: href)
            #expect(cursor.seek(to: ref))
            #expect(cursor.next()?.object == a)
        }

        @Test func refinedAudioReference() throws {
            let href = try #require(AnyURL(string: "audio.mp3"))
            let a = gno(audio: "audio.mp3#t=0,1")
            let b = gno(audio: "audio.mp3#t=1,2")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))

            let ref = AudioReference(
                href: href,
                temporal: .clip(TemporalClip(start: 1, end: 2))
            )
            #expect(cursor.seek(to: ref))
            #expect(cursor.next()?.object == b)
        }

        @Test func refinedWebReference() throws {
            let href = try #require(AnyURL(string: "chapter.html"))
            let a = gno(audio: "a.mp3", textRef: "chapter.html#para1")
            let b = gno(audio: "b.mp3", textRef: "chapter.html#para2")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))

            let ref = WebReference(href: href, cssSelector: CSSSelector(id: "para2"))
            #expect(cursor.seek(to: ref))
            #expect(cursor.next()?.object == b)
        }

        @Test func refinedImageReference() throws {
            let href = try #require(AnyURL(string: "page.jpg"))
            let a = gno(audio: "a.mp3", imgRef: "page.jpg#xywh=0,0,100,100")
            let b = gno(audio: "b.mp3", imgRef: "page.jpg#xywh=100,0,100,100")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))

            let ref = ImageReference(
                href: href,
                spatial: SpatialSelector(x: 100, y: 0, width: 100, height: 100, unit: .pixel)
            )
            #expect(cursor.seek(to: ref))
            #expect(cursor.next()?.object == b)
        }

        @Test func unknownReferenceReturnsFalse() throws {
            let a = gno(audio: "a.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))

            let ref = try AudioReference(href: #require(AnyURL(string: "unknown.mp3")))
            #expect(!cursor.seek(to: ref))
        }

        @Test func videoReferenceReturnsFalse() {
            // VideoReference is not handled by matches(node:reference:) — the
            // default: false branch must return false without crashing.
            let a = gno(audio: "a.mp3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))
            let ref = VideoReference(href: AnyURL(string: "video.mp4")!)
            #expect(!cursor.seek(to: ref))
        }

        @Test func seekThenContinue() throws {
            let href = try #require(AnyURL(string: "chapter.html"))
            let a = gno(audio: "a.mp3", textRef: "chapter.html#p1")
            let b = gno(audio: "b.mp3", textRef: "chapter.html#p2")
            let c = gno(audio: "c.mp3", textRef: "chapter.html#p3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))

            let ref = WebReference(href: href, cssSelector: CSSSelector(id: "p2"))
            #expect(cursor.seek(to: ref))
            // next() returns the sought node...
            #expect(cursor.next()?.object == b)
            // ...and continues from there.
            #expect(cursor.next()?.object == c)
            #expect(cursor.next() == nil)
        }

        // MARK: 1 — seek() then previous()

        @Test func seekThenPreviousFromMiddle() throws {
            // Flat: [A, B, C]. Seeking B positions the cursor just before B
            // (current = A). previous() should return A then nil.
            let href = try #require(AnyURL(string: "chapter.html"))
            let a = gno(audio: "a.mp3", textRef: "chapter.html#p1")
            let b = gno(audio: "b.mp3", textRef: "chapter.html#p2")
            let c = gno(audio: "c.mp3", textRef: "chapter.html#p3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))

            #expect(cursor.seek(to: WebReference(href: href, cssSelector: CSSSelector(id: "p2"))))
            #expect(cursor.previous()?.object == a)
            #expect(cursor.previous() == nil)
            // Forward navigation still works from the beginning.
            #expect(cursor.next()?.object == a)
        }

        @Test func seekThenPreviousFromFirst() throws {
            // Seeking the very first node positions the cursor before the start
            // (current = nil). previous() should return nil immediately.
            let href = try #require(AnyURL(string: "chapter.html"))
            let a = gno(audio: "a.mp3", textRef: "chapter.html#p1")
            let b = gno(audio: "b.mp3", textRef: "chapter.html#p2")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b))

            #expect(cursor.seek(to: WebReference(href: href, cssSelector: CSSSelector(id: "p1"))))
            #expect(cursor.previous() == nil)
            // next() still returns the first node.
            #expect(cursor.next()?.object == a)
        }

        // MARK: 2 — re-seeking mid-traversal

        @Test func reSeekAfterNavigation() throws {
            let href = try #require(AnyURL(string: "chapter.html"))
            let a = gno(audio: "a.mp3", textRef: "chapter.html#p1")
            let b = gno(audio: "b.mp3", textRef: "chapter.html#p2")
            let c = gno(audio: "c.mp3", textRef: "chapter.html#p3")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, b, c))

            // Advance past the first two nodes.
            _ = cursor.next() // A
            _ = cursor.next() // B

            // Seek back to A — should fully reset traversal state.
            #expect(cursor.seek(to: WebReference(href: href, cssSelector: CSSSelector(id: "p1"))))
            #expect(cursor.next()?.object == a)
            #expect(cursor.next()?.object == b)
            #expect(cursor.next()?.object == c)
            #expect(cursor.next() == nil)
        }

        // MARK: 4 — seek into nested node + ancestors

        @Test func seekNestedNodeAncestors() throws {
            // Tree: A → [B → [D, E], C]
            // Seeking D should position the cursor so next() returns D with
            // ancestors [A, B].
            let href = try #require(AnyURL(string: "audio.mp3"))
            let d = gno(audio: "audio.mp3#t=2,3")
            let e = gno(audio: "audio.mp3#t=3,4")
            let b = gno(audio: "audio.mp3#t=1,2", children: [d, e])
            let a = gno(audio: "audio.mp3#t=0,1", children: [b])
            let c = gno(audio: "audio.mp3#t=4,5")
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a, c))

            let ref = AudioReference(
                href: href,
                temporal: .clip(TemporalClip(start: 2, end: 3))
            )
            #expect(cursor.seek(to: ref))
            let node = cursor.next()
            #expect(node?.object == d)
            #expect(node?.ancestors == [a, b])
        }
    }

    // MARK: - 5 — previous() ancestors across two sibling subtrees

    struct PreviousAncestorsAcrossSubtrees {
        @Test func twoSubtrees() {
            // Tree: A → [B → [D, E], C → [F, G]]
            // DFS pre-order: A, B, D, E, C, F, G
            // Reverse:       G, F, C, E, D, B, A
            let d = gno(audio: "d.mp3")
            let e = gno(audio: "e.mp3")
            let f = gno(audio: "f.mp3")
            let g = gno(audio: "g.mp3")
            let b = gno(audio: "b.mp3", children: [d, e])
            let c = gno(audio: "c.mp3", children: [f, g])
            let a = gno(audio: "a.mp3", children: [b, c])
            let cursor = GuidedNavigationDocumentCursor(document: gnd(a))

            _ = cursor.next() // A
            _ = cursor.next() // B
            _ = cursor.next() // D
            _ = cursor.next() // E
            _ = cursor.next() // C
            _ = cursor.next() // F
            _ = cursor.next() // G

            let nodeG = cursor.previous()
            #expect(nodeG?.object == g)
            #expect(nodeG?.ancestors == [a, c])

            let nodeF = cursor.previous()
            #expect(nodeF?.object == f)
            #expect(nodeF?.ancestors == [a, c])

            let nodeC = cursor.previous()
            #expect(nodeC?.object == c)
            #expect(nodeC?.ancestors == [a])

            let nodeE = cursor.previous()
            #expect(nodeE?.object == e)
            #expect(nodeE?.ancestors == [a, b])

            let nodeD = cursor.previous()
            #expect(nodeD?.object == d)
            #expect(nodeD?.ancestors == [a, b])

            let nodeB = cursor.previous()
            #expect(nodeB?.object == b)
            #expect(nodeB?.ancestors == [a])

            let nodeA = cursor.previous()
            #expect(nodeA?.object == a)
            #expect(nodeA?.ancestors == [])

            #expect(cursor.previous() == nil)
        }
    }
}

// MARK: - Helpers

private func gno(
    audio: String? = nil,
    imgRef: String? = nil,
    textRef: String? = nil,
    roles: [ContentRole] = [],
    children: [GuidedNavigationObject] = []
) -> GuidedNavigationObject {
    guard let obj = GuidedNavigationObject(
        refs: GuidedNavigationObject.Refs(
            text: textRef.flatMap { AnyURL(string: $0).map { WebReference(href: $0) } },
            image: imgRef.flatMap { AnyURL(string: $0).map { ImageReference(href: $0) } },
            audio: audio.flatMap { AnyURL(string: $0).map { AudioReference(href: $0) } }
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
