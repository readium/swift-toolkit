//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import ReadiumShared
import Testing

@MainActor
enum GuidedAudioSequencerTests {
    @MainActor struct Next {
        @Test func singleNodeSingleFile() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a))]
            )
            let clip = await seq.next()
            #expect(clip != nil)
            #expect(clip?.clip.link.href == "audio.mp3")
            #expect(clip?.nodes.count == 1)
            #expect(clip?.nodes[0].object == a)
            #expect(clip?.clip.segments.count == 1)
            #expect(clip?.clip.segments[0].start == 0)
            #expect(clip?.clip.segments[0].end == 1)
            #expect(await seq.next() == nil)
        }

        @Test func multipleNodesSameFile() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#p2")
            let c = gno(audioRef: "audio.mp3#t=2,3", textRef: "ch.xhtml#p3")
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a, b, c))]
            )
            let clip = await seq.next()
            // Three sync points → three segments, each derived from the node's
            // audio reference.
            #expect(clip?.nodes.count == 3)
            #expect(clip?.clip.segments.count == 3)
            #expect(clip?.nodes[0].object == a)
            #expect(clip?.clip.segments[0].start == 0)
            #expect(clip?.clip.segments[0].end == 1)
            #expect(clip?.nodes[1].object == b)
            #expect(clip?.clip.segments[1].start == 1)
            #expect(clip?.clip.segments[1].end == 2)
            #expect(clip?.nodes[2].object == c)
            #expect(clip?.clip.segments[2].start == 2)
            #expect(clip?.clip.segments[2].end == 3)
            #expect(await seq.next() == nil)
        }

        @Test func twoFilesReturnsTwoClips() async {
            let a = gno(audioRef: "ch1-audio.mp3#t=0,1", textRef: "ch1.xhtml#p1")
            let b = gno(audioRef: "ch2-audio.mp3#t=0,1", textRef: "ch2.xhtml#p1")
            let seq = makeSequencer(
                readingOrder: ["ch1.xhtml", "ch2.xhtml"],
                resources: ["ch1-audio.mp3", "ch2-audio.mp3"],
                gnds: [
                    "ch1.xhtml": ("ch1-gnd.json", gnd(a)),
                    "ch2.xhtml": ("ch2-gnd.json", gnd(b)),
                ]
            )
            let clip1 = await seq.next()
            #expect(clip1?.nodes.count == 1)
            #expect(clip1?.nodes[0].object == a)
            let clip2 = await seq.next()
            #expect(clip2?.nodes.count == 1)
            #expect(clip2?.nodes[0].object == b)
            #expect(await seq.next() == nil)
        }

        /// A single audio track may span multiple XHTML chapters. Nodes in
        /// adjacent GNDs referencing the same audio file must coalesce into one
        /// ``GuidedAudioClip``.
        @Test func crossesGNDBoundary() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch1.xhtml#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch2.xhtml#p1")
            let seq = makeSequencer(
                readingOrder: ["ch1.xhtml", "ch2.xhtml"],
                resources: ["audio.mp3"],
                gnds: [
                    "ch1.xhtml": ("ch1-gnd.json", gnd(a)),
                    "ch2.xhtml": ("ch2-gnd.json", gnd(b)),
                ]
            )
            let clip = await seq.next()
            #expect(clip?.nodes.count == 2)
            #expect(clip?.clip.segments.count == 2)
            #expect(clip?.nodes[0].object == a)
            #expect(clip?.nodes[1].object == b)
            #expect(await seq.next() == nil)
        }

        @Test func returnsNilAtEnd() async {
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")))]
            )
            _ = await seq.next()
            #expect(await seq.next() == nil)
            #expect(await seq.next() == nil)
        }

        @Test func skippedNodeExcludedFromClip() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#fn1", roles: [.footnote])
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a, b))],
                skippedRoles: [.footnote]
            )
            // The footnote node must not appear in nodes or segments.
            let clip = await seq.next()
            #expect(clip?.nodes.count == 1)
            #expect(clip?.clip.segments.count == 1)
            #expect(clip?.nodes[0].object == a)
        }
    }

    @MainActor struct Previous {
        @Test func returnsNilAtStart() async {
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")))]
            )
            #expect(await seq.previous() == nil)
            #expect(await seq.previous() == nil)
        }

        @Test func singleNodeSingleFile() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a))]
            )
            _ = await seq.next()
            let clip = await seq.previous()
            #expect(clip?.nodes.count == 1)
            #expect(clip?.nodes[0].object == a)
        }

        @Test func multipleNodesSameFile() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#p2")
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a, b))]
            )
            _ = await seq.next()
            let clip = await seq.previous()
            #expect(clip?.nodes.count == 2)
            #expect(clip?.clip.segments.count == 2)
            #expect(clip?.nodes[0].object == a)
            #expect(clip?.nodes[1].object == b)
        }

        @Test func twoFilesReturnsTwoClips() async {
            let a = gno(audioRef: "ch1-audio.mp3#t=0,1", textRef: "ch1.xhtml#p1")
            let b = gno(audioRef: "ch2-audio.mp3#t=0,1", textRef: "ch2.xhtml#p1")
            let seq = makeSequencer(
                readingOrder: ["ch1.xhtml", "ch2.xhtml"],
                resources: ["ch1-audio.mp3", "ch2-audio.mp3"],
                gnds: [
                    "ch1.xhtml": ("ch1-gnd.json", gnd(a)),
                    "ch2.xhtml": ("ch2-gnd.json", gnd(b)),
                ]
            )
            _ = await seq.next() // ch1
            _ = await seq.next() // ch2
            let clip2 = await seq.previous()
            let clip1 = await seq.previous()
            #expect(clip2?.nodes[0].object == b)
            #expect(clip1?.nodes[0].object == a)
            #expect(await seq.previous() == nil)
        }

        @Test func skippedNodeExcludedFromClip() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#fn1", roles: [.footnote])
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a, b))],
                skippedRoles: [.footnote]
            )
            _ = await seq.next()
            let clip = await seq.previous()
            #expect(clip?.nodes.count == 1)
            #expect(clip?.nodes[0].object == a)
        }
    }

    @MainActor struct SeekToNode {
        @Test func findsNode() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#p2")
            let c = gno(audioRef: "audio.mp3#t=2,3", textRef: "ch.xhtml#p3")
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a, b, c))]
            )
            // Seek directly to the middle sync point by index path.
            let result = await seq.seek(to: [0, 1])
            #expect(result != nil)
            #expect(result?.startIndex == 1)
            #expect(result?.clip.nodes[1].object == b)
        }

        @Test func returnsNilForOutOfBoundsIndexPath() async {
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")))]
            )
            #expect(await seq.seek(to: [0, 99]) == nil)
        }

        @Test func skippedNodeAdvancesToNextNonSkipped() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#fn1", roles: [.footnote])
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#p1")
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a, b))],
                skippedRoles: [.footnote]
            )
            // Seeking to the footnote node must advance to the next non-skipped
            // sync point.
            let result = await seq.seek(to: [0, 0])
            #expect(result != nil)
            #expect(result?.clip.nodes.first?.object == b)
        }
    }

    @MainActor struct SeekToReference {
        @Test func findsReference() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let b = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#p2")
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a, b))]
            )
            let ref = WebReference(href: "ch.xhtml", cssSelector: CSSSelector(id: "p2"))
            let result = await seq.seek(to: ref)
            #expect(result != nil)
            #expect(result?.startIndex == 1)
            #expect(result?.clip.nodes[1].object == b)
        }

        @Test func returnsNilForUnknownReference() async {
            let a = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let seq = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(a))]
            )
            let ref = WebReference(href: "unknown.xhtml")
            let result = await seq.seek(to: ref)
            #expect(result == nil)
        }
    }

    /// Nodes with a `sequence` role have their audio reference ignored; their
    /// children are included in the clip as if the sequence wrapper did not
    /// exist.
    @MainActor struct SequenceRole {
        /// A sequence node with an audio ref spanning its children must not
        /// contribute a segment; only the children's segments appear.
        @Test func sequenceAudioRefIgnored() async {
            let child1 = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let child2 = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#p2")
            let seq = gno(
                audioRef: "audio.mp3#t=0,2",
                textRef: "ch.xhtml#section",
                roles: [.sequence],
                children: [child1, child2]
            )
            let sequencer = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(seq))]
            )
            let clip = await sequencer.next()
            #expect(clip?.nodes.count == 2)
            #expect(clip?.clip.segments.count == 2)
            #expect(clip?.nodes[0].object == child1)
            #expect(clip?.clip.segments[0].start == 0)
            #expect(clip?.clip.segments[0].end == 1)
            #expect(clip?.nodes[1].object == child2)
            #expect(clip?.clip.segments[1].start == 1)
            #expect(clip?.clip.segments[1].end == 2)
        }

        /// Seeking to a child of a sequence node returns the full-file clip
        /// with the correct startIndex pointing to that child.
        @Test func seekToChildOfSequence() async {
            let child0 = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let child1 = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#p2")
            let child2 = gno(audioRef: "audio.mp3#t=2,3", textRef: "ch.xhtml#p3")
            let seq = gno(
                audioRef: "audio.mp3#t=0,3",
                roles: [.sequence],
                children: [child0, child1, child2]
            )
            let sequencer = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(seq))]
            )
            // Index path [0, 0, 1] → GND 0, seq at tree[0], child1 at tree[0][1].
            let result = await sequencer.seek(to: [0, 0, 1])
            #expect(result != nil)
            #expect(result?.startIndex == 1)
            #expect(result?.clip.nodes.count == 3)
            #expect(result?.clip.nodes[0].object == child0)
            #expect(result?.clip.nodes[1].object == child1)
            #expect(result?.clip.nodes[2].object == child2)
        }

        /// Seeking to a sequence node itself advances to the first non-skipped
        /// child and returns the full-file clip with startIndex 0.
        @Test func seekToSequenceNodeAdvancesToFirstChild() async {
            let child0 = gno(audioRef: "audio.mp3#t=0,1", textRef: "ch.xhtml#p1")
            let child1 = gno(audioRef: "audio.mp3#t=1,2", textRef: "ch.xhtml#p2")
            let seq = gno(
                audioRef: "audio.mp3#t=0,2",
                roles: [.sequence],
                children: [child0, child1]
            )
            let sequencer = makeSequencer(
                readingOrder: ["ch.xhtml"],
                resources: ["audio.mp3"],
                gnds: ["ch.xhtml": ("ch-gnd.json", gnd(seq))]
            )
            let result = await sequencer.seek(to: [0, 0])
            #expect(result?.startIndex == 0)
            #expect(result?.clip.nodes.first?.object == child0)
        }
    }
}

// MARK: - Helpers

/// Builds a ``GuidedAudioSequencer`` from simplified EPUB+MediaOverlays test
/// parameters.
///
/// - Parameters:
///   - readingOrder: XHTML HREF strings for the publication reading order and
///     the ``GuidedNavigationCursor``.
///   - resources: Audio file HREFs added to the publication resources.
///   - gnds: Maps reading-order XHTML HREF → (GND HREF, document).
///   - skippedRoles: Roles passed to ``GuidedAudioSequencer/skippedRoles``.
///   - failing: GND HREF strings that should throw on fetch.
@MainActor
private func makeSequencer(
    readingOrder: [String],
    resources: [String] = [],
    gnds: [String: (String, GuidedNavigationDocument)],
    skippedRoles: Set<ContentRole> = [],
    failing: Set<String> = []
) -> GuidedAudioSequencer {
    let publication = Publication(manifest: Manifest(
        metadata: Metadata(title: ""),
        links: [],
        readingOrder: readingOrder.map { Link(href: $0) },
        resources: resources.map { Link(href: $0) }
    ))
    let cursor = makeCursor(readingOrder: readingOrder, gnds: gnds, failing: failing)
    return GuidedAudioSequencer(publication: publication, cursor: cursor, skippedRoles: skippedRoles)
}

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
    textRef: String? = nil,
    roles: [ContentRole] = [],
    children: [GuidedNavigationObject] = []
) -> GuidedNavigationObject {
    guard let obj = GuidedNavigationObject(
        refs: GuidedNavigationObject.Refs(
            text: textRef.flatMap { AnyURL(string: $0).map { WebReference(href: $0) } },
            image: nil,
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

private struct MockProvider: GuidedNavigationDocumentProvider {
    let gnds: [String: (href: AnyURL, doc: GuidedNavigationDocument)]
    let roMap: [String: String]
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
