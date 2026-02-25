//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumAudioNavigator
import ReadiumShared
import Testing

@Suite struct GuidedNavigationCursorTests {
    @Suite("next()") struct Next {
        @Test("flat GND returns items in order")
        func flatGNDInOrder() async throws {
            let doc = gnd(
                gno(audio: "audio.mp3#t=0,1"),
                gno(audio: "audio.mp3#t=1,2"),
                gno(audio: "audio.mp3#t=2,3")
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["chapter1.html"],
                gnds: ["chapter1.html": doc]
            ))

            let i1 = await cursor.next()
            let i2 = await cursor.next()
            let i3 = await cursor.next()
            let end = await cursor.next()

            #expect(try i1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "audio.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(try i2?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "audio.mp3")),
                temporal: .clip(TemporalClip(start: 1, end: 2))
            )))
            #expect(try i3?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "audio.mp3")),
                temporal: .clip(TemporalClip(start: 2, end: 3))
            )))
            #expect(end == nil)
        }

        @Test("sequence containers are traversed but not yielded")
        func sequenceContainerSkipped() async throws {
            let doc = gnd(
                gno(
                    audio: "chapter.mp3#t=0,10",
                    roles: [.sequence],
                    children: [
                        gno(audio: "chapter.mp3#t=0,5"),
                        gno(audio: "chapter.mp3#t=5,10"),
                    ]
                )
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["chapter1.html"],
                gnds: ["chapter1.html": doc]
            ))

            let i1 = await cursor.next()
            let i2 = await cursor.next()
            let end = await cursor.next()

            // The sequence container itself should NOT be yielded; children should be.
            #expect(try i1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "chapter.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 5))
            )))
            #expect(try i2?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "chapter.mp3")),
                temporal: .clip(TemporalClip(start: 5, end: 10))
            )))
            #expect(end == nil)
        }

        @Test("non-sequence container with audio IS yielded before its children")
        func nonSequenceContainerYielded() async throws {
            let doc = gnd(
                gno(
                    audio: "chapter.mp3#t=0,10",
                    roles: [.chapter],
                    children: [
                        gno(audio: "chapter.mp3#t=1,2"),
                    ]
                )
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["chapter1.html"],
                gnds: ["chapter1.html": doc]
            ))

            let i1 = await cursor.next()
            let i2 = await cursor.next()
            let end = await cursor.next()

            #expect(try i1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "chapter.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 10))
            )))
            #expect(try i2?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "chapter.mp3")),
                temporal: .clip(TemporalClip(start: 1, end: 2))
            )))
            #expect(end == nil)
        }

        @Test("items across two resources")
        func acrossResources() async throws {
            let doc1 = gnd(gno(audio: "a1.mp3#t=0,1"))
            let doc2 = gnd(gno(audio: "a2.mp3#t=0,1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html", "r2.html"],
                gnds: ["r1.html": doc1, "r2.html": doc2]
            ))

            let i1 = await cursor.next()
            let i2 = await cursor.next()
            let end = await cursor.next()

            #expect(try i1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a1.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(try i2?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a2.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(end == nil)
        }

        @Test("skips resource with no GND document")
        func skipsResourceWithNoGND() async throws {
            let doc2 = gnd(gno(audio: "a2.mp3#t=0,1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html", "r2.html"],
                gnds: ["r2.html": doc2] // r1.html has no GND
            ))

            let i1 = await cursor.next()
            let end = await cursor.next()

            #expect(try i1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a2.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(end == nil)
        }

        @Test("skips resource when GND fetch fails")
        func skipsResourceOnFetchError() async throws {
            let doc2 = gnd(gno(audio: "a2.mp3#t=0,1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html", "r2.html"],
                gnds: ["r2.html": doc2],
                failing: ["r1.html"] // r1.html fetch fails with an error
            ))

            let i1 = await cursor.next()
            let end = await cursor.next()

            // The fetch error for r1.html is non-blocking; the cursor moves on.
            #expect(try i1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a2.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(end == nil)
        }

        @Test("returns nil at end")
        func returnsNilAtEnd() async {
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: [:]
            ))
            let result = await cursor.next()
            #expect(result == nil)
        }
    }

    @Suite("previous()") struct Previous {
        @Test("reverses next()")
        func reversesNext() async throws {
            let doc = gnd(
                gno(audio: "audio.mp3#t=0,1"),
                gno(audio: "audio.mp3#t=1,2")
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["chapter1.html"],
                gnds: ["chapter1.html": doc]
            ))

            _ = await cursor.next()
            _ = await cursor.next()

            let i2 = await cursor.previous()
            let i1 = await cursor.previous()
            let start = await cursor.previous()

            #expect(try i2?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "audio.mp3")),
                temporal: .clip(TemporalClip(start: 1, end: 2))
            )))
            #expect(try i1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "audio.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(start == nil)
        }

        @Test("wraps across resource boundary")
        func wrapsAcrossResourceBoundary() async throws {
            let doc1 = gnd(gno(audio: "a1.mp3#t=0,1"))
            let doc2 = gnd(gno(audio: "a2.mp3#t=0,1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html", "r2.html"],
                gnds: ["r1.html": doc1, "r2.html": doc2]
            ))

            _ = await cursor.next()
            _ = await cursor.next()

            let i2 = await cursor.previous()
            let i1 = await cursor.previous()
            let start = await cursor.previous()

            #expect(try i2?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a2.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(try i1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a1.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(start == nil)
        }

        @Test("crossing to previous resource lands on last item")
        func crossingToPreviousResourceLandsOnLastItem() async throws {
            let doc1 = gnd(
                gno(audio: "a1.mp3#t=0,1"),
                gno(audio: "a1.mp3#t=1,2"),
                gno(audio: "a1.mp3#t=2,3")
            )
            let doc2 = gnd(gno(audio: "a2.mp3#t=0,1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html", "r2.html"],
                gnds: ["r1.html": doc1, "r2.html": doc2]
            ))

            // Exhaust both resources forward.
            _ = await cursor.next() // a1 t=0,1
            _ = await cursor.next() // a1 t=1,2
            _ = await cursor.next() // a1 t=2,3
            _ = await cursor.next() // a2 t=0,1

            // Go backward: first step returns the item we just passed in doc2.
            let fromDoc2 = await cursor.previous()
            // Crossing the boundary: must return the *last* item of doc1, not the first.
            let lastOfDoc1 = await cursor.previous()

            #expect(try fromDoc2?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a2.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
            #expect(try lastOfDoc1?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a1.mp3")),
                temporal: .clip(TemporalClip(start: 2, end: 3))
            )))
        }

        @Test("returns nil at start")
        func returnsNilAtStart() async {
            let doc = gnd(gno(audio: "audio.mp3#t=0,1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))
            let result = await cursor.previous()
            #expect(result == nil)
        }

        @Test("returns nil when called repeatedly at start")
        func returnsNilWhenRepeatedAtStart() async {
            let doc = gnd(gno(audio: "audio.mp3#t=0,1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))
            // Multiple calls at the boundary must not corrupt state.
            _ = await cursor.previous()
            _ = await cursor.previous()
            let result = await cursor.next()
            #expect(result != nil)
        }
    }

    @Suite("seek(to:)") struct Seek {
        @Test("unrefined reference seeks to start of resource")
        func seekUnrefinedMovesToStart() async throws {
            let doc = gnd(
                gno(audio: "a.mp3#t=0,1", textRef: "r1.html#para1"),
                gno(audio: "a.mp3#t=1,2", textRef: "r1.html#para2")
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let ref = try WebReference(href: #require(AnyURL(string: "r1.html")))
            let result = await cursor.seek(to: ref)
            let item = await cursor.next()

            #expect(result == true)
            #expect(try item?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
        }

        @Test("unrefined reference seeks to start of a different resource")
        func seekUnrefinedDifferentResource() async throws {
            let doc1 = gnd(gno(audio: "a1.mp3#t=0,1", textRef: "r1.html#para1"))
            let doc2 = gnd(gno(audio: "a2.mp3#t=0,1", textRef: "r2.html#para1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html", "r2.html"],
                gnds: ["r1.html": doc1, "r2.html": doc2]
            ))
            _ = await cursor.next()
            _ = await cursor.next()

            let ref = try WebReference(href: #require(AnyURL(string: "r1.html")))
            let result = await cursor.seek(to: ref)
            let item = await cursor.next()

            #expect(result == true)
            #expect(try item?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a1.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
        }

        @Test("HTML ID seek finds matching item")
        func seekHTMLIDFindsMatchingItem() async throws {
            let doc = gnd(
                gno(audio: "a.mp3#t=0,1", textRef: "r1.html#para1"),
                gno(audio: "a.mp3#t=1,2", textRef: "r1.html#para2")
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let ref = try WebReference(
                href: #require(AnyURL(string: "r1.html")),
                cssSelector: CSSSelector(id: "para2")
            )
            let result = await cursor.seek(to: ref)
            let item = await cursor.next()

            #expect(result == true)
            #expect(try item?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a.mp3")),
                temporal: .clip(TemporalClip(start: 1, end: 2))
            )))
        }

        @Test("HTML ID seek on first item")
        func seekHTMLIDFirstItem() async throws {
            let doc = gnd(
                gno(audio: "a.mp3#t=0,1", textRef: "r1.html#para1"),
                gno(audio: "a.mp3#t=1,2", textRef: "r1.html#para2")
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let ref = try WebReference(
                href: #require(AnyURL(string: "r1.html")),
                cssSelector: CSSSelector(id: "para1")
            )
            let result = await cursor.seek(to: ref)
            let item = await cursor.next()

            #expect(result == true)
            #expect(try item?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
        }

        @Test("seek fails for unknown resource, state unchanged")
        func seekFailsUnknownResource() async throws {
            let doc = gnd(gno(audio: "a.mp3#t=0,1", textRef: "r1.html#para1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let ref = try WebReference(href: #require(AnyURL(string: "unknown.html")))
            let result = await cursor.seek(to: ref)
            let item = await cursor.next()

            #expect(result == false)
            // State unchanged: cursor still starts from beginning of r1.html
            #expect(try item?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
        }

        @Test("seek fails when HTML ID not found in GND, next() state unchanged")
        func seekFailsHTMLIDNotFound() async throws {
            let doc = gnd(gno(audio: "a.mp3#t=0,1", textRef: "r1.html#para1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let ref = try WebReference(
                href: #require(AnyURL(string: "r1.html")),
                cssSelector: CSSSelector(id: "nonexistent")
            )
            let result = await cursor.seek(to: ref)
            let item = await cursor.next()

            #expect(result == false)
            // State unchanged: cursor still starts from beginning
            #expect(try item?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
        }

        @Test("seek fails when HTML ID not found in GND, previous() state unchanged")
        func seekFailsHTMLIDNotFoundPrevious() async throws {
            let doc = gnd(
                gno(audio: "a.mp3#t=0,1", textRef: "r1.html#para1"),
                gno(audio: "a.mp3#t=1,2", textRef: "r1.html#para2")
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            // Advance past the first item so previous() has something to return.
            _ = await cursor.next()

            let ref = try WebReference(
                href: #require(AnyURL(string: "r1.html")),
                cssSelector: CSSSelector(id: "nonexistent")
            )
            let result = await cursor.seek(to: ref)
            // State unchanged: previous() still returns the item we just advanced past.
            let item = await cursor.previous()

            #expect(result == false)
            #expect(try item?.content == .audio(AudioReference(
                href: #require(AnyURL(string: "a.mp3")),
                temporal: .clip(TemporalClip(start: 0, end: 1))
            )))
        }
    }

    @Suite("PlaybackItem conversion") struct Conversion {
        @Test("enclosingRoles propagated from parent containers")
        func enclosingRolesPropagated() async {
            // chapter (roles: [.chapter]) contains
            //   section (roles: [.section, .foreword]) contains
            //     paragraph (roles: [.paragraph])
            let doc = gnd(
                gno(
                    audio: "chapter.mp3#t=0,10",
                    roles: [.chapter],
                    children: [
                        gno(
                            audio: "chapter.mp3#t=0,5",
                            roles: [.section, .foreword],
                            children: [
                                gno(audio: "chapter.mp3#t=1,2", roles: [.paragraph]),
                            ]
                        ),
                    ]
                )
            )
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            // First item: the chapter container itself, no enclosing roles.
            let chapter = await cursor.next()
            // Second item: the sidebar inside the chapter; enclosing = [.chapter].
            let sidebar = await cursor.next()
            // Third item: the paragraph inside the section; enclosing = [.section, .foreword, .chapter].
            let para = await cursor.next()

            #expect(chapter?.roles == [.chapter])
            #expect(chapter?.enclosingRoles == [])
            #expect(sidebar?.roles == [.section, .foreword])
            #expect(sidebar?.enclosingRoles == [.chapter])
            #expect(para?.roles == [.paragraph])
            #expect(para?.enclosingRoles == [.section, .foreword, .chapter])
        }

        @Test("textAlternate has correct CSS selector from plain fragment")
        func textAlternateCSSSelectorFromFragment() async {
            let doc = gnd(gno(
                audio: "audio.mp3#t=0,1",
                textRef: "chapter.html#section1"
            ))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let item = await cursor.next()
            let textAlt = item?.textAlternate as? WebReference

            #expect(textAlt?.href == AnyURL(string: "chapter.html")!)
            #expect(textAlt?.cssSelector == CSSSelector(id: "section1"))
        }

        @Test("imageAlternate has spatial selector from xywh fragment")
        func imageAlternateHasSpatialSelector() async {
            let doc = gnd(gno(
                audio: "audio.mp3#t=0,1",
                imgRef: "page.jpg#xywh=10,20,100,200"
            ))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let item = await cursor.next()

            let imgAlt = item?.imageAlternate as? ImageReference
            #expect(imgAlt?.href == AnyURL(string: "page.jpg")!)
            #expect(imgAlt?.spatial == SpatialSelector(x: 10, y: 20, width: 100, height: 200, unit: .pixel))
        }

        @Test("temporal clip parsed from audio URL fragment")
        func temporalClipParsedFromFragment() async throws {
            let doc = gnd(gno(audio: "audio.mp3#t=3.5,7.2"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let item = await cursor.next()
            guard case let .audio(mediaRef) = item?.content else {
                Issue.record("Expected audio content")
                return
            }

            #expect(try mediaRef.href.isEquivalentTo(#require(AnyURL(string: "audio.mp3"))))
            #expect(mediaRef.temporal == .clip(TemporalClip(start: 3.5, end: 7.2)))
        }

        @Test("text content created from GNO text node")
        func textContentFromGNO() async {
            let doc = gnd(gno(plainText: "Hello world"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let item = await cursor.next()
            guard case let .text(text) = item?.content else {
                Issue.record("Expected text content")
                return
            }

            #expect(text.text == "Hello world")
        }

        @Test("node with only refs.text is not playable")
        func textRefOnlyNotPlayable() async {
            let doc = gnd(gno(textRef: "chapter.html#para1"))
            var cursor = GuidedNavigationCursor(publication: publication(
                readingOrder: ["r1.html"],
                gnds: ["r1.html": doc]
            ))

            let item = await cursor.next()
            #expect(item == nil)
        }
    }
}

// MARK: - Helpers

private func gno(
    audio: String? = nil,
    text: String? = nil,
    imgRef: String? = nil,
    textRef: String? = nil,
    plainText: String? = nil,
    ssml: String? = nil,
    roles: [ContentRole] = [],
    children: [GuidedNavigationObject] = []
) -> GuidedNavigationObject {
    guard let obj = GuidedNavigationObject(
        refs: GuidedNavigationObject.Refs(
            text: textRef.flatMap(AnyURL.init(string:)),
            img: imgRef.flatMap(AnyURL.init(string:)),
            audio: audio.flatMap(AnyURL.init(string:)),
            video: nil
        ),
        text: GuidedNavigationObject.Text(
            plain: plainText,
            ssml: ssml
        ),
        roles: roles,
        children: children
    ) else {
        preconditionFailure("Invalid GuidedNavigationObject in test: all content fields are nil")
    }
    return obj
}

private func gnd(_ objects: GuidedNavigationObject...) -> GuidedNavigationDocument {
    GuidedNavigationDocument(guided: objects)
}

private func publication(
    readingOrder: [String],
    gnds: [String: GuidedNavigationDocument],
    failing: Set<String> = []
) -> Publication {
    let links = readingOrder.map { href in Link(href: href) }
    let manifest = Manifest(
        metadata: Metadata(title: "Test"),
        readingOrder: links
    )
    return Publication(
        manifest: manifest,
        servicesBuilder: PublicationServicesBuilder(
            guidedNavigation: { _ in MockGuidedNavigationService(gnds: gnds, failing: failing) }
        )
    )
}

private final class MockGuidedNavigationService: GuidedNavigationService {
    let gnds: [String: GuidedNavigationDocument]
    let failing: Set<String>

    init(gnds: [String: GuidedNavigationDocument], failing: Set<String> = []) {
        self.gnds = gnds
        self.failing = failing
    }

    var hasGuidedNavigation: Bool {
        !gnds.isEmpty
    }

    func hasGuidedNavigation(for href: any URLConvertible) -> Bool {
        gnds[href.anyURL.string] != nil
    }

    func guidedNavigationDocument(for href: any URLConvertible) async throws(ReadError) -> GuidedNavigationDocument? {
        let key = href.anyURL.removingFragment().string
        if failing.contains(key) {
            throw ReadError.access(AccessError.fileSystem(
                FileSystemError.fileNotFound(nil)
            ))
        }
        return gnds[key]
    }
}
