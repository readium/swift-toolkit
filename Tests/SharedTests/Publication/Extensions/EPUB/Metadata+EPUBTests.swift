//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import Testing

enum MetadataEPUBTests {
    @Suite("EPUBMediaOverlay") enum EPUBMediaOverlayTests {
        @Suite("JSON parsing") struct JSONParsing {
            @Test("full content")
            func fullContent() throws {
                let sut = try EPUBMediaOverlay(json: [
                    "activeClass": "-epub-media-overlay-active",
                    "playbackActiveClass": "-epub-media-overlay-playing",
                ])

                #expect(sut?.activeClass == "-epub-media-overlay-active")
                #expect(sut?.playbackActiveClass == "-epub-media-overlay-playing")
            }

            @Test("only activeClass returns non-nil")
            func onlyActiveClassReturnsNonNil() throws {
                let sut = try EPUBMediaOverlay(json: ["activeClass": "-epub-media-overlay-active"])
                #expect(sut?.activeClass == "-epub-media-overlay-active")
                #expect(sut?.playbackActiveClass == nil)
            }

            @Test("only playbackActiveClass returns non-nil")
            func onlyPlaybackActiveClassReturnsNonNil() throws {
                let sut = try EPUBMediaOverlay(json: ["playbackActiveClass": "-epub-media-overlay-playing"])
                #expect(sut?.playbackActiveClass == "-epub-media-overlay-playing")
                #expect(sut?.activeClass == nil)
            }

            @Test("empty dictionary returns nil")
            func emptyDictionaryReturnsNil() throws {
                #expect(try EPUBMediaOverlay(json: [:]) == nil)
            }

            @Test("nil returns nil")
            func nilReturnsNil() throws {
                #expect(try EPUBMediaOverlay(json: nil as JSONValue?) == nil)
            }

            @Test("non-dictionary returns nil")
            func nonDictionaryReturnsNil() throws {
                #expect(try EPUBMediaOverlay(json: "not-a-dict") == nil)
            }
        }

        @Suite("JSON encoding") struct JSONEncoding {
            @Test("round-trip preserves all values")
            func roundTrip() throws {
                let original = EPUBMediaOverlay(
                    activeClass: "-epub-media-overlay-active",
                    playbackActiveClass: "-epub-media-overlay-playing"
                )

                #expect(try EPUBMediaOverlay(json: original.jsonValue) == original)
            }

            @Test("nil values are omitted from JSON")
            func omitsNilValues() {
                let sut = EPUBMediaOverlay(activeClass: "-epub-media-overlay-active")
                #expect(sut.jsonObject["playbackActiveClass"] == nil)
            }
        }
    }

    @Suite("Metadata.mediaOverlay accessor") struct MediaOverlayAccessorTests {
        @Test("returns nil when absent")
        func returnsNilWhenAbsent() {
            let metadata = Metadata(title: "Test")
            #expect(metadata.mediaOverlay == nil)
        }

        @Test("returns value when present in otherMetadata")
        func returnsValueWhenPresent() {
            var metadata = Metadata(title: "Test")
            metadata.otherMetadata["mediaOverlay"] = .object([
                "activeClass": .string("-epub-media-overlay-active"),
            ])

            #expect(metadata.mediaOverlay?.activeClass == "-epub-media-overlay-active")
        }
    }

    @Suite("Metadata.epubLayout") struct EPUBLayoutTests {
        @Test("defaults to reflowable", arguments: [nil, Layout.reflowable, Layout.scrolled])
        func defaultsToReflowable(layout: Layout?) {
            let metadata = Metadata(title: "Test", layout: layout)
            #expect(metadata.epubLayout == .reflowable)
        }

        @Test("is fixed when the layout is fixed")
        func fixed() {
            let metadata = Metadata(title: "Test", layout: .fixed)
            #expect(metadata.epubLayout == .fixed)
        }

        @Test("of a link uses the link override")
        func linkOverrideWins() {
            var fixedLink = Link(href: "fixed.xhtml")
            fixedLink.properties.epubLayout = .fixed
            var reflowableLink = Link(href: "reflowable.xhtml")
            reflowableLink.properties.epubLayout = .reflowable

            let fixedMetadata = Metadata(title: "Test", layout: .fixed)
            let reflowableMetadata = Metadata(title: "Test", layout: .reflowable)

            #expect(fixedMetadata.epubLayout(of: reflowableLink) == .reflowable)
            #expect(reflowableMetadata.epubLayout(of: fixedLink) == .fixed)
        }

        @Test("of a link falls back to fixed metadata")
        func linkFallsBackToFixed() {
            let metadata = Metadata(title: "Test", layout: .fixed)
            #expect(metadata.epubLayout(of: Link(href: "res.xhtml")) == .fixed)
        }

        @Test("of a link falls back to reflowable", arguments: [nil, Layout.reflowable, Layout.scrolled])
        func linkFallsBackToReflowable(layout: Layout?) {
            let metadata = Metadata(title: "Test", layout: layout)
            #expect(metadata.epubLayout(of: Link(href: "res.xhtml")) == .reflowable)
        }
    }
}
