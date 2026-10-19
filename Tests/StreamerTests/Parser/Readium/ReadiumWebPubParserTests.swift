//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@_spi(ExperimentalTimeline) import ReadiumShared
@testable import ReadiumStreamer
@_spi(ExperimentalTimeline) import TestSupport
import Testing

enum ReadiumWebPubParserTests {
    struct Formats {
        @Test func refusesNonReadiumWebPub() async throws {
            let asset: Asset = try await .container(ZIPArchiveOpener().open(
                resource: FileResource(file: fixtures.url(for: "audiotest.zab")),
                format: Format(specifications: .zip, .informalAudiobook, mediaType: .zab, fileExtension: "zab")
            ).get())

            let result = await makeParser().parse(asset: asset, warnings: nil)

            guard case .failure(.formatNotSupported) = result else {
                Issue.record("Expected a formatNotSupported error, got \(result)")
                return
            }
        }

        @Test func acceptsManifest() async throws {
            let asset: Asset = .resource(ResourceAsset(
                resource: FileResource(file: fixtures.url(for: "flatland.json")),
                format: Format(specifications: .json, .rwpm, mediaType: .readiumWebPubManifest, fileExtension: "json")
            ))

            _ = try await makeParser().parse(asset: asset, warnings: nil).get()
        }

        @Test func acceptsPackage() async throws {
            let asset: Asset = try await .container(ZIPArchiveOpener().open(
                resource: FileResource(file: fixtures.url(for: "audiotest.lcpa")),
                format: Format(specifications: .zip, .rpf, .lcp, mediaType: .lcpProtectedAudiobook, fileExtension: "lcpa")
            ).get())

            _ = try await makeParser().parse(asset: asset, warnings: nil).get()
        }
    }

    struct TableOfContents {
        struct ManifestExample: Sendable, CustomTestStringConvertible {
            let name: String
            /// Media type of the reading order resources.
            var mediaType = "audio/mpeg"
            /// JSON of the `toc` of the manifest.
            var toc = "[]"
            var generatesTableOfContentsFromReadingOrder = true
            let expectedTOC: [Link]
            /// Outline of the expected timeline, `nil` for no timeline.
            let expectedTimeline: [String]?

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            ManifestExample(
                name: "audiobook without a table of contents uses the reading order titles",
                expectedTOC: [Link(href: "part1", title: "Part 1", duration: 10), Link(href: "part2", title: "Part 2")],
                expectedTimeline: ["0 Part 1 → part1", "1 Part 2 → part2"]
            ),
            ManifestExample(
                name: "audiobook keeps its table of contents",
                toc: #"[{"href": "part1#t=10", "title": "Chapter 1"}]"#,
                expectedTOC: [Link(href: "part1#t=10", title: "Chapter 1")],
                expectedTimeline: ["0 Chapter 1 → part1#t=10"]
            ),
            ManifestExample(
                name: "the option off disables both fallbacks",
                generatesTableOfContentsFromReadingOrder: false,
                expectedTOC: [],
                expectedTimeline: []
            ),
            ManifestExample(
                name: "other publication without a table of contents has none",
                mediaType: "text/html",
                expectedTOC: [],
                expectedTimeline: []
            ),
        ])
        func usesTheReadingOrderTitlesOfAnAudiobookWithoutOne(_ example: ManifestExample) async throws {
            let publication = try await parsePackage(manifest: """
            {
              "metadata": {"title": "Publication"},
              "readingOrder": [
                {"href": "part1", "type": "\(example.mediaType)", "title": "Part 1", "duration": 10},
                {"href": "part2", "type": "\(example.mediaType)", "title": "Part 2"}
              ],
              "toc": \(example.toc)
            }
            """, generatesTableOfContentsFromReadingOrder: example.generatesTableOfContentsFromReadingOrder)

            #expect(publication.manifest.tableOfContents == example.expectedTOC)
            #expect(try await publication.timeline()?.outline == example.expectedTimeline)
        }
    }

    struct Timelines {
        struct ProfileExample: Sendable, CustomTestStringConvertible {
            let name: String
            /// Media type of the reading order resource.
            let mediaType: String
            /// JSON of the `conformsTo` of the manifest.
            var conformsTo = "[]"
            /// Whether the package is protected with LCP.
            var isLCP = false
            /// Type name of the expected timeline service, `nil` for none.
            let expected: String?

            var testDescription: String {
                name
            }
        }

        @Test(arguments: [
            ProfileExample(name: "audiobook", mediaType: "audio/mpeg", expected: "AudioTimelineService"),
            ProfileExample(name: "HTML resources", mediaType: "text/html", expected: "WebTimelineService"),
            ProfileExample(
                name: "EPUB profile without HTML resources",
                mediaType: "image/svg+xml",
                conformsTo: #"["https://readium.org/webpub-manifest/profiles/epub"]"#,
                expected: "WebTimelineService"
            ),
            ProfileExample(name: "SVG resources without the EPUB profile", mediaType: "image/svg+xml", expected: nil),
            ProfileExample(name: "comic", mediaType: "image/png", expected: nil),
            ProfileExample(name: "PDF", mediaType: "application/pdf", expected: nil),
            ProfileExample(name: "LCP-protected PDF", mediaType: "application/pdf", isLCP: true, expected: "PDFTimelineService"),
        ])
        func serviceDependsOnTheProfileAndResources(_ example: ProfileExample) async throws {
            let publication = try await parsePackage(manifest: """
            {
              "metadata": {"title": "Publication", "conformsTo": \(example.conformsTo)},
              "readingOrder": [{"href": "part1", "type": "\(example.mediaType)"}]
            }
            """, isLCP: example.isLCP)

            #expect(publication.findService(TimelineService.self).map { "\(type(of: $0))" } == example.expected)
        }
    }
}

// MARK: - Helpers

private let fixtures = Fixtures()

private func makeParser(generatesTableOfContentsFromReadingOrder: Bool = true) -> ReadiumWebPubParser {
    ReadiumWebPubParser(
        pdfFactory: DefaultPDFDocumentFactory(),
        httpClient: DefaultHTTPClient(),
        config: .init(generatesAudiobookTableOfContentsFromReadingOrder: generatesTableOfContentsFromReadingOrder)
    )
}

/// Parses a package holding only the given manifest.
private func parsePackage(manifest: String, generatesTableOfContentsFromReadingOrder: Bool = true, isLCP: Bool = false) async throws -> Publication {
    let asset: Asset = .container(ContainerAsset(
        container: SingleResourceContainer(
            resource: DataResource(string: manifest),
            at: AnyURL(string: "manifest.json")!
        ),
        format: isLCP
            ? Format(specifications: .zip, .rpf, .lcp, mediaType: .lcpProtectedPDF, fileExtension: "lcpdf")
            : Format(specifications: .zip, .rpf, mediaType: .readiumWebPub, fileExtension: "webpub")
    ))
    return try await makeParser(generatesTableOfContentsFromReadingOrder: generatesTableOfContentsFromReadingOrder)
        .parse(asset: asset, warnings: nil).get().build()
}
