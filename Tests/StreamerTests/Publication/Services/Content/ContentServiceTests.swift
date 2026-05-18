//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
@testable import ReadiumStreamer
import Testing
import TestPublications

enum ContentServiceTests {
    struct ReflowableEPUB {
        let url: URL = TestPublications.url(for: "childrens-literature.epub")

        @Test func defaultContentServiceIsAvailable() async throws {
            let publication = try await openPublication(url: url)
            #expect(publication.content() != nil)
        }

        /// Iterates until elements from all three spine resources have been observed,
        /// verifying that the iterator crosses resource boundaries correctly.
        @Test func crossResourceIteration() async throws {
            let publication = try await openPublication(url: url)
            let content = try #require(publication.content())
            let iter = content.iterator()

            var hrefs: [String] = []
            while let href = try await iter.next()?.locator.href.string {
                if hrefs.last != href {
                    hrefs.append(href)
                }
            }

            #expect(hrefs == [
                "EPUB/cover.xhtml",
                "EPUB/nav.xhtml",
                "EPUB/s04.xhtml",
            ])
        }

        /// Starts iteration from a CSS selector locator inside a real EPUB resource
        /// and verifies the first element matches the targeted heading.
        @Test func startingFromLocator() async throws {
            let publication = try await openPublication(url: url)
            let startLocator = Locator(
                href: "EPUB/s04.xhtml",
                mediaType: .xhtml,
                locations: Locator.Locations(otherLocations: ["cssSelector": "#pgepubid00498 > h3"])
            )
            let content = try #require(publication.content(from: startLocator))
            let iter = content.iterator()
            let element = try #require(try await iter.next())
            let text = try #require(element as? TextualContentElement).text
            #expect(text == "INTRODUCTORY")
        }

        /// Advances two elements then reverses one, verifying that `previous()` returns
        /// the same element as the first `next()` call.
        @Test func bidirectionalNavigation() async throws {
            let publication = try await openPublication(url: url)
            let startLocator = Locator(href: "EPUB/s04.xhtml", mediaType: .xhtml)
            let content = try #require(publication.content(from: startLocator))
            let iter = content.iterator()
            let first = try #require(try await iter.next())
            _ = try await iter.next()
            let backToFirst = try #require(try await iter.previous())
            #expect(first.locator == backToFirst.locator)
        }
    }

    struct FixedLayoutEPUB {
        let url: FileURL = Fixtures(path: "ContentService").url(for: "fxl-content-service-test.epub")

        @Test func defaultContentServiceIsAvailable() async throws {
            let publication = try await openPublication(url: url.url)
            #expect(publication.content() != nil)
        }

        /// Exhausts the FXL publication and verifies that elements from both pages
        /// appear in reading order.
        @Test func crossPageIteration() async throws {
            let publication = try await openPublication(url: url.url)
            let content = try #require(publication.content())
            let iter = content.iterator()

            var hrefs: [String] = []
            while let href = try await iter.next()?.locator.href.string {
                if hrefs.last != href {
                    hrefs.append(href)
                }
            }
            #expect(hrefs == ["EPUB/page1.xhtml", "EPUB/page2.xhtml"])
        }
    }
}

// MARK: - Helpers

private func openPublication(url: URL) async throws -> Publication {
    let format = Format(specifications: .zip, .epub, mediaType: .epub, fileExtension: "epub")
    let container = try await ZIPArchiveOpener().open(
        resource: FileResource(file: FileURL(url: url)!),
        format: format
    ).get()
    let asset: Asset = .container(container)
    return try await EPUBParser().parse(asset: asset, warnings: nil).get().build()
}
