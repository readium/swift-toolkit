//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import Testing

struct OPFParserTests {
    @Test func parseMinimalOPF() throws {
        let sut = try parseManifest("minimal", at: "EPUB/content.opf")

        #expect(sut.manifest == Manifest(
            metadata: Metadata(
                conformsTo: [.epub],
                title: "Alice's Adventures in Wonderland",
                layout: .reflowable
            ),
            readingOrder: [
                link(href: "EPUB/titlepage.xhtml"),
            ]
        ))
    }

    struct Version {
        @Test func parseEPUB2Version() throws {
            let sut = try parseManifest("version-epub2")
            #expect(sut.version == "2.0.1")
        }

        @Test func parseEPUB3Version() throws {
            let sut = try parseManifest("version-epub3")
            #expect(sut.version == "3.0")
        }

        @Test func parseDefaultEPUBVersion() throws {
            let sut = try parseManifest("version-default")
            #expect(sut.version == "1.2")
        }
    }

    struct Links {
        @Test func parseLinks() throws {
            let sut = try parseManifest("links", at: "EPUB/content.opf").manifest

            #expect(sut.links == [])
            #expect(sut.readingOrder == [
                link(href: "titlepage.xhtml", mediaType: .xhtml),
                Link(
                    href: "EPUB/chapter01.xhtml",
                    mediaType: .xhtml,
                    alternates: [
                        Link(href: "EPUB/chapter01.smil", mediaType: .smil),
                    ]
                ),
            ])
            #expect(sut.resources == [
                link(href: "EPUB/fonts/MinionPro.otf", mediaType: MediaType("application/vnd.ms-opentype")!),
                link(href: "EPUB/nav.xhtml", mediaType: .xhtml, rels: [.contents]),
                link(href: "style.css", mediaType: .css),
                link(href: "EPUB/chapter02.xhtml", mediaType: .xhtml),
                Link(href: "EPUB/chapter02.smil", mediaType: .smil, duration: 1949.0),
                link(href: "EPUB/images/alice01a.png", mediaType: .png, rels: [.cover]),
                link(href: "EPUB/images/alice02a.gif", mediaType: .gif),
                link(href: "EPUB/nomediatype.txt"),
            ])
        }

        @Test func parseLinksFromSpine() throws {
            let sut = try parseManifest("links-spine", at: "EPUB/content.opf").manifest

            #expect(sut.readingOrder == [
                link(href: "EPUB/titlepage.xhtml"),
            ])
        }

        @Test func parseLinkProperties() throws {
            let sut = try parseManifest("links-properties", at: "EPUB/content.opf").manifest

            #expect(sut.readingOrder.count == 8)
            #expect(sut.readingOrder[0] == link(href: "EPUB/chapter01.xhtml", rels: [.contents], properties: Properties([
                "contains": ["mathml"],
                "layout": "fixed",
                "page": "right",
            ])))
            #expect(sut.readingOrder[1] == link(href: "EPUB/chapter02.xhtml", properties: Properties([
                "contains": ["remote-resources"],
                "layout": "reflowable",
                "page": "left",
            ])))
            #expect(sut.readingOrder[2] == link(href: "EPUB/chapter03.xhtml", properties: Properties([
                "contains": ["js", "svg"],
                "page": "center",
            ])))
            #expect(sut.readingOrder[3] == link(href: "EPUB/chapter04.xhtml", properties: Properties([
                "contains": ["onix", "xmp"],
            ])))
            #expect(sut.readingOrder[4] == link(href: "EPUB/chapter05.xhtml", properties: Properties([
                "page": "left",
            ])))
            #expect(sut.readingOrder[5] == link(href: "EPUB/chapter06.xhtml", properties: Properties([
                "page": "right",
            ])))
            #expect(sut.readingOrder[6] == link(href: "EPUB/chapter07.xhtml"))
            #expect(sut.readingOrder[7] == link(href: "EPUB/chapter08.xhtml"))
        }
    }

    struct Cover {
        @Test func parseEPUB2Cover() throws {
            let sut = try parseManifest("cover-epub2", at: "EPUB/content.opf").manifest

            #expect(sut.resources == [
                link(href: "EPUB/cover.jpg", mediaType: .jpeg, rels: [.cover]),
            ])
        }

        @Test func parseEPUB3Cover() throws {
            let sut = try parseManifest("cover-epub3", at: "EPUB/content.opf").manifest

            #expect(sut.resources == [
                link(href: "EPUB/cover.jpg", mediaType: .jpeg, rels: [.cover]),
            ])
        }
    }

    struct FallbackHandling {
        /// When an image is in the spine with an HTML fallback, the image should be
        /// in readingOrder and HTML should be added as an alternate.
        @Test func parseImageInSpineWithHTMLFallback() throws {
            let sut = try parseManifest("fallback-image-in-spine", at: "EPUB/content.opf").manifest

            #expect(sut.readingOrder.count == 2)

            // First image in spine
            #expect(sut.readingOrder[0].href == "EPUB/page1.jpg")
            #expect(sut.readingOrder[0].mediaType == .jpeg)
            #expect(sut.readingOrder[0].alternates == [
                Link(href: "EPUB/page1.xhtml", mediaType: .xhtml),
            ])

            // Second image in spine
            #expect(sut.readingOrder[1].href == "EPUB/page2.png")
            #expect(sut.readingOrder[1].mediaType == .png)
            #expect(sut.readingOrder[1].alternates == [
                Link(href: "EPUB/page2.xhtml", mediaType: .xhtml),
            ])

            // HTML fallbacks should not be in resources
            #expect(sut.resources.isEmpty)
        }

        /// When HTML is in the spine with an image fallback, we swap: the image
        /// should be in readingOrder and HTML should be added as an alternate.
        @Test func parseHTMLInSpineWithImageFallback() throws {
            let sut = try parseManifest("fallback-html-in-spine", at: "EPUB/content.opf").manifest

            #expect(sut.readingOrder.count == 2)

            // First item: image swapped into readingOrder, HTML as alternate
            #expect(sut.readingOrder[0].href == "EPUB/page1.jpg")
            #expect(sut.readingOrder[0].mediaType == .jpeg)
            #expect(sut.readingOrder[0].alternates == [
                Link(href: "EPUB/page1.xhtml", mediaType: .xhtml),
            ])

            // Second item: image swapped into readingOrder, HTML as alternate
            #expect(sut.readingOrder[1].href == "EPUB/page2.png")
            #expect(sut.readingOrder[1].mediaType == .png)
            #expect(sut.readingOrder[1].alternates == [
                Link(href: "EPUB/page2.xhtml", mediaType: .xhtml),
            ])

            // Fallback images should not be in resources
            #expect(sut.resources.isEmpty)
        }

        /// General fallback handling: any fallback should be translated to an
        /// alternate.
        @Test func parseGeneralFallbackAsAlternate() throws {
            let sut = try parseManifest("fallback-general", at: "EPUB/content.opf").manifest

            #expect(sut.readingOrder.count == 2)

            // First item: XHTML with XHTML fallback
            #expect(sut.readingOrder[0].href == "EPUB/chapter1.xhtml")
            #expect(sut.readingOrder[0].mediaType == .xhtml)
            #expect(sut.readingOrder[0].alternates == [
                Link(href: "EPUB/chapter1-alt.xhtml", mediaType: .xhtml),
            ])

            // Second item: XHTML with PDF fallback
            #expect(sut.readingOrder[1].href == "EPUB/chapter2.xhtml")
            #expect(sut.readingOrder[1].mediaType == .xhtml)
            #expect(sut.readingOrder[1].alternates == [
                Link(href: "EPUB/chapter2.pdf", mediaType: .pdf),
            ])

            // Fallback resources should not be in resources
            #expect(sut.resources.isEmpty)
        }
    }

    struct DivinaInference {
        /// When all spine items are bitmaps, the metadata should have:
        /// - `layout = .fixed` to use the FXL navigator
        /// - `.divina` added to `conformsTo`
        @Test func parseAllImagesInSpineSetsFixedLayoutAndDivinaProfile() throws {
            let sut = try parseManifest("all-images-in-spine", at: "EPUB/content.opf").manifest

            // Should have fixed layout
            #expect(sut.metadata.layout == .fixed)

            // Should conform to both EPUB and Divina
            #expect(sut.metadata.conformsTo.contains(.epub))
            #expect(sut.metadata.conformsTo.contains(.divina))

            // Reading order should contain all images
            #expect(sut.readingOrder.count == 3)
            #expect(sut.readingOrder[0].mediaType == .jpeg)
            #expect(sut.readingOrder[1].mediaType == .png)
            #expect(sut.readingOrder[2].mediaType == .gif)
        }

        /// When not all spine items are bitmaps, the metadata should NOT have
        /// `.divina` profile and layout should remain reflowable.
        @Test func parseMixedSpineDoesNotSetDivinaProfile() throws {
            let sut = try parseManifest("fallback-image-html-mixed", at: "EPUB/content.opf").manifest

            // Should have reflowable layout (default)
            #expect(sut.metadata.layout == .reflowable)

            // Should only conform to EPUB, not Divina
            #expect(sut.metadata.conformsTo.contains(.epub))
            #expect(!sut.metadata.conformsTo.contains(.divina))
        }
    }

    struct MediaOverlays {
        @Test func parseMediaOverlaysSmilAsAlternate() throws {
            let sut = try parseManifest("media-overlays", at: "EPUB/content.opf").manifest

            // SMIL should be an alternate of each reading order item, not in resources
            #expect(sut.readingOrder[0].href == "EPUB/chapter01.xhtml")
            #expect(sut.readingOrder[0].alternates == [
                Link(href: "EPUB/chapter01.smil", mediaType: .smil, duration: 1425.0),
            ])
            #expect(sut.readingOrder[1].href == "EPUB/chapter02.xhtml")
            #expect(sut.readingOrder[1].alternates == [
                Link(href: "EPUB/chapter02.smil", mediaType: .smil, duration: 524.0),
            ])
            #expect(sut.resources.isEmpty)
        }
    }
}

// MARK: - Helpers

private let fixtures = Fixtures(path: "OPF")

private func parseManifest(_ name: String, at path: String = "EPUB/content.opf", displayOptions: String? = nil) throws -> (manifest: Manifest, version: String) {
    let parts = try OPFParser(
        baseURL: RelativeURL(path: path)!,
        data: fixtures.data(at: "\(name).opf"),
        displayOptionsData: displayOptions.map { fixtures.data(at: "\($0).xml") },
        encryptions: [:]
    ).parsePublication()

    return (Manifest(
        metadata: parts.metadata,
        readingOrder: parts.readingOrder,
        resources: parts.resources
    ), parts.version)
}

private func link(href: String, mediaType: MediaType? = nil, templated: Bool = false, title: String? = nil, rels: [LinkRelation] = [], properties: Properties = .init(), children: [Link] = []) -> Link {
    Link(href: href, mediaType: mediaType, templated: templated, title: title, rels: rels, properties: properties, children: children)
}
