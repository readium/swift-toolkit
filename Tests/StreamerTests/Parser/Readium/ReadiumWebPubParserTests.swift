//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
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
        /// Each rule holds its name, the media type of the reading order, the
        /// `toc` of the manifest and the expected table of contents.
        @Test(arguments: [
            (
                "audiobook without a table of contents uses the reading order titles",
                "audio/mpeg",
                "[]",
                [Link(href: "part1", title: "Part 1", duration: 10), Link(href: "part2", title: "Part 2")]
            ),
            (
                "audiobook keeps its table of contents",
                "audio/mpeg",
                #"[{"href": "part1#t=10", "title": "Chapter 1"}]"#,
                [Link(href: "part1#t=10", title: "Chapter 1")]
            ),
            (
                "other publication without a table of contents has none",
                "text/html",
                "[]",
                []
            ),
        ] as [(String, String, String, [Link])])
        func usesTheReadingOrderTitlesOfAnAudiobookWithoutOne(rule: String, mediaType: String, toc: String, expected: [Link]) async throws {
            let manifest = try await parsePackage(manifest: """
            {
              "metadata": {"title": "Publication"},
              "readingOrder": [
                {"href": "part1", "type": "\(mediaType)", "title": "Part 1", "duration": 10},
                {"href": "part2", "type": "\(mediaType)", "title": "Part 2"}
              ],
              "toc": \(toc)
            }
            """)

            #expect(manifest.tableOfContents == expected)
        }
    }
}

// MARK: - Helpers

private let fixtures = Fixtures()

private func makeParser() -> ReadiumWebPubParser {
    ReadiumWebPubParser(pdfFactory: DefaultPDFDocumentFactory(), httpClient: DefaultHTTPClient())
}

/// Parses a package holding only the given manifest.
private func parsePackage(manifest: String) async throws -> Manifest {
    let asset: Asset = .container(ContainerAsset(
        container: SingleResourceContainer(
            resource: DataResource(string: manifest),
            at: AnyURL(string: "manifest.json")!
        ),
        format: Format(specifications: .zip, .rpf, mediaType: .readiumWebPub, fileExtension: "webpub")
    ))
    return try await makeParser().parse(asset: asset, warnings: nil).get().build().manifest
}
