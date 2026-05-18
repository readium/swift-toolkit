//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
@testable import ReadiumStreamer
import Testing

/// Configuration for a single `SearchService` test run.
struct SearchServiceTestConfig: CustomTestStringConvertible {
    /// Human-readable description of the config, used for test reporting.
    let testDescription: String

    /// Factory closure to create the `SearchService` instance.
    let serviceFactory: SearchServiceFactory

    /// Whether the service supports matching results spanning multiple
    /// elements within the same resource (e.g., across `<p>` boundaries).
    let supportsCrossElementSearch: Bool

    /// Whether the service supports matching results spanning multiple
    /// resources.
    let supportsCrossResourceSearch: Bool

    /// Whether the service supports case-sensitive search.
    let supportsCaseSensitivity: Bool

    /// Whether the service supports diacritic-sensitive search.
    let supportsDiacriticSensitivity: Bool

    /// Whether the service supports exact match search.
    let supportsExactMatch: Bool

    /// Whether the service supports regular expression search.
    let supportsRegularExpression: Bool

    /// Whether the service ignores fallback content during search.
    ///
    /// `<audio src="">Fallback content that should not be searchable</audio>`
    let ignoresFallbackContent: Bool
}

/// Tests for `SearchService` implementations.
///
/// **Fixture layout:**
///
/// `search-reflowable.epub` (3 chapters):
/// - chapter1: "Alice went to wonderland. The café was lovely." + `<img alt="invisible alt text"/>` + `<p>The quick</p><p>brown fox.</p>` (two paragraphs for cross-element test)
/// - chapter2: "ALICE found a naïve cat on 2024-01-15." + `<audio fallback>` + "The sun" (ends with "sun" for cross-resource test)
/// - chapter3: "rise greeted alice who likes wonderland very much." (starts with "rise" for cross-resource test)
///
/// `search-fxl.epub` (4 pages, pre-paginated):
/// - page1: "Once upon a time there was a dragon named" (ends with "named" for cross-resource test)
/// - page2: "Bella who lived in a cave." (starts with "Bella" for cross-resource test)
/// - page3: "Bella loved to fly over the mountains." + `<img alt="hidden dragon image"/>`
/// - page4: "The end of Bella's story."
struct SearchServiceTests {
    /// Add new configs here as additional ``SearchService`` implementations are
    /// introduced.
    static func configs(snippetLength: Int = 200) -> [SearchServiceTestConfig] {
        [
            contentSearchServiceConfig(snippetLength: snippetLength),
//            stringSearchServiceConfig(snippetLength: snippetLength),
        ]
    }

    static func contentSearchServiceConfig(snippetLength: Int) -> SearchServiceTestConfig {
        .init(
            testDescription: "ContentSearchService",
            serviceFactory: ContentSearchService.makeFactory(snippetLength: snippetLength),
            supportsCrossElementSearch: true,
            supportsCrossResourceSearch: false,
            supportsCaseSensitivity: true,
            supportsDiacriticSensitivity: true,
            supportsExactMatch: true,
            supportsRegularExpression: true,
            ignoresFallbackContent: true
        )
    }

//    static func stringSearchServiceConfig(snippetLength: Int) -> SearchServiceTestConfig {
//        .init(
//            testDescription: "StringSearchService",
//            serviceFactory: StringSearchService.makeFactory(snippetLength: snippetLength),
//            supportsCrossElementSearch: false,
//            supportsCrossResourceSearch: false,
//            supportsCaseSensitivity: true,
//            supportsDiacriticSensitivity: true,
//            supportsExactMatch: true,
//            supportsRegularExpression: true,
//            ignoresFallbackContent: false
//        )
//    }

    @Test(arguments: configs())
    func searchServiceIsAvailable(config: SearchServiceTestConfig) async throws {
        let pub = try await openPublication(.reflowable, config: config)
        #expect(pub.isSearchable)
    }

    struct BasicSearch {
        @Test(arguments: configs())
        func basicSearch(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "wonderland")

            let first = try #require(results.first)
            #expect(first.href.string == "EPUB/chapter1.xhtml")
            #expect(first.text.highlight == "wonderland")
        }

        @Test(arguments: configs())
        func noResults(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "xyzzy_nonexistent")
            #expect(results.isEmpty)
        }
    }

    struct MultipleResources {
        /// "wonderland" appears in chapter1 and chapter3, in reading order.
        @Test(arguments: configs())
        func multipleResourcesReflowable(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "wonderland")

            try #require(results.count == 2)
            #expect(results[0].href.string == "EPUB/chapter1.xhtml")
            #expect(results[1].href.string == "EPUB/chapter3.xhtml")
        }

        /// "Bella" appears in pages 2, 3 and 4 (as a substring of "Bella's"),
        /// in reading order.
        @Test(arguments: configs())
        func multipleResourcesFXL(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.fxl, config: config)
            let results = try await search(pub, query: "Bella")

            try #require(results.count == 3)
            #expect(results[0].href.string == "EPUB/page2.xhtml")
            #expect(results[1].href.string == "EPUB/page3.xhtml")
            #expect(results[2].href.string == "EPUB/page4.xhtml")
        }
    }

    struct CrossResourceSearch {
        /// "sunrise" spans the chapter2/chapter3 boundary ("sun" + "rise").
        /// It never appears within a single resource so only a cross-resource
        /// algorithm can find it.
        @Test(arguments: configs())
        func crossResourceSearchReflowable(config: SearchServiceTestConfig) async throws {
            guard config.supportsCrossResourceSearch else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "sunrise")

            try #require(results.count == 1)
            #expect(results[0].href.string == "EPUB/chapter2.xhtml")
        }

        /// "named Bella" spans the page1/page2 boundary.
        /// It never appears within a single resource.
        @Test(arguments: configs())
        func crossResourceSearchFXL(config: SearchServiceTestConfig) async throws {
            guard config.supportsCrossResourceSearch else { return }
            let pub = try await openPublication(.fxl, config: config)
            let results = try await search(pub, query: "named Bella")

            try #require(results.count == 1)
            #expect(results[0].href.string == "EPUB/page1.xhtml")
        }
    }

    struct CrossElementSearch {
        /// "quick brown" is split across two `<p>` elements in chapter1
        /// (`<p>The quick</p><p>brown fox.</p>`). It never appears within a
        /// single element, so only a service with a cross-element algorithm can
        /// find it.
        @Test(arguments: configs())
        func crossElementSearch(config: SearchServiceTestConfig) async throws {
            guard config.supportsCrossElementSearch else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "quick brown")

            try #require(results.count == 1)
            #expect(results[0].href.string == "EPUB/chapter1.xhtml")
            #expect(results[0].text.highlight == "quick brown")
        }

        /// A cross-element match should not carry a `cssSelector` because the
        /// renderer would scope its text search to a single DOM node that
        /// cannot contain the full highlight.
        @Test(arguments: configs())
        func crossElementMatchHasNoCssSelector(config: SearchServiceTestConfig) async throws {
            guard config.supportsCrossElementSearch else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "quick brown")

            let locator = try #require(results.first)
            #expect(locator.locations.otherLocations["cssSelector"] == nil)
        }

        // FIXME: To restore after dropping strippedForSnippetPositioning
        /// A single-element match should preserve the `cssSelector` set by the
        /// HTML content iterator.
//        @Test(arguments: configs())
//        func singleElementMatchPreservesCssSelector(config: SearchServiceTestConfig) async throws {
//            guard config.supportsCrossElementSearch else { return }
//            let pub = try await openPublication(.reflowable, config: config)
//            let results = try await search(pub, query: "wonderland")
//
//            let locator = try #require(results.first)
//            #expect(locator.locations.otherLocations["cssSelector"] != nil)
//        }
    }

    struct CaseSensitivity {
        /// Case-insensitive (default) search finds "Alice" (ch1), "ALICE" (ch2)
        /// and "alice" (ch3).
        @Test(arguments: configs())
        func caseInsensitiveSearch(config: SearchServiceTestConfig) async throws {
            guard config.supportsCaseSensitivity else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "alice", options: .init(caseSensitive: false))

            try #require(results.count == 3)
            #expect(results[0].href.string == "EPUB/chapter1.xhtml")
            #expect(results[0].text.highlight == "Alice")
            #expect(results[1].href.string == "EPUB/chapter2.xhtml")
            #expect(results[1].text.highlight == "ALICE")
            #expect(results[2].href.string == "EPUB/chapter3.xhtml")
            #expect(results[2].text.highlight == "alice")
        }

        /// Case-sensitive search for "alice" finds only the lowercase variant
        /// in chapter3.
        @Test(arguments: configs())
        func caseSensitiveSearch(config: SearchServiceTestConfig) async throws {
            guard config.supportsCaseSensitivity else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "alice", options: .init(caseSensitive: true))

            try #require(results.count == 1)
            #expect(results[0].href.string == "EPUB/chapter3.xhtml")
            #expect(results[0].text.highlight == "alice")
        }
    }

    struct DiacriticSensitivity {
        /// Diacritic-insensitive search for "cafe" matches "café" in chapter1.
        @Test(arguments: configs())
        func diacriticInsensitiveSearch(config: SearchServiceTestConfig) async throws {
            guard config.supportsDiacriticSensitivity else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "cafe", options: .init(diacriticSensitive: false))

            try #require(results.count == 1)
            #expect(results[0].href.string == "EPUB/chapter1.xhtml")
            #expect(results[0].text.highlight == "café")
        }

        /// Diacritic-sensitive search for "cafe" does not match "café".
        @Test(arguments: configs())
        func diacriticSensitiveSearch(config: SearchServiceTestConfig) async throws {
            guard config.supportsDiacriticSensitivity else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "cafe", options: .init(diacriticSensitive: true))
            #expect(results.isEmpty)
        }
    }

    struct ExactMatch {
        /// Exact (literal) match for "Alice" finds only the exact-case
        /// occurrence in chapter1, not "ALICE" (chapter2) or "alice"
        /// (chapter3).
        ///
        /// `exact: true` uses NSString `.literal` comparison, which disables
        /// all folding (case and diacritics) simultaneously.
        @Test(arguments: configs())
        func exactMatch(config: SearchServiceTestConfig) async throws {
            guard config.supportsExactMatch else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "Alice", options: .init(exact: true))

            try #require(results.count == 1)
            #expect(results[0].href.string == "EPUB/chapter1.xhtml")
            #expect(results[0].text.highlight == "Alice")
        }
    }

    struct RegularExpression {
        /// Regex `\d{4}-\d{2}-\d{2}` matches the ISO date "2024-01-15" in
        /// chapter2.
        @Test(arguments: configs())
        func regularExpressionSearch(config: SearchServiceTestConfig) async throws {
            guard config.supportsRegularExpression else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: #"\d{4}-\d{2}-\d{2}"#, options: .init(regularExpression: true))

            try #require(results.count == 1)
            #expect(results[0].href.string == "EPUB/chapter2.xhtml")
            #expect(results[0].text.highlight == "2024-01-15")
        }
    }

    struct SnippetExtraction {
        /// A match surrounded by text should populate `before` and `after`.
        @Test(arguments: configs())
        func snippetBeforeAndAfter(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            // "wonderland" in chapter1: "Alice went to wonderland. The café was
            // lovely."
            let results = try await search(pub, query: "wonderland")

            let first = try #require(results.first { $0.href.string == "EPUB/chapter1.xhtml" })
            #expect(first.text.highlight == "wonderland")
            #expect(first.text.before != nil)
            #expect(first.text.after != nil)
        }

        /// A match at the very start of a resource should have nil `before`.
        @Test(arguments: configs())
        func snippetNoBeforeAtResourceStart(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            // chapter3 starts with "rise greeted alice..."
            let results = try await search(pub, query: "rise greeted", options: .init(caseSensitive: false))

            let first = try #require(results.first { $0.href.string == "EPUB/chapter3.xhtml" })
            #expect(first.text.highlight?.lowercased() == "rise greeted")
            #expect(first.text.before == nil)
        }

        /// A match at the very end of a resource should have nil `after`.
        @Test(arguments: configs())
        func snippetNoAfterAtResourceEnd(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            // chapter2 ends with "The sun"
            let results = try await search(pub, query: "sun", options: .init(caseSensitive: false))

            let first = try #require(results.first { $0.href.string == "EPUB/chapter2.xhtml" })
            #expect(first.text.highlight?.lowercased() == "sun")
            #expect(first.text.after == nil)
        }

        /// A cross-element match should have a `before` snippet that extends
        /// to the requested snippet length and reflects actual preceding
        /// element text.
        @Test(arguments: configs())
        func crossElementSnippetBeforeHasFullContext(config: SearchServiceTestConfig) async throws {
            guard config.supportsCrossElementSearch else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "quick brown")

            let first = try #require(results.first)
            #expect(first.text.highlight == "quick brown")
            #expect(first.text.before == "Alice went to wonderland. The café was lovely. The ")
        }

        /// When a space falls at exactly `snippetLength` chars before the match,
        /// the before snippet must extend past it to the prior word boundary
        /// rather than stopping at the space character.
        ///
        /// chapter3: "rise greeted alice who likes wonderland very much."
        /// With snippetLength=8, position 9 from "alice" is the space between
        /// "rise" and "greeted" — a hard-truncating guard (`> 0`) breaks there,
        /// producing "greeted ". The correct word-boundary guard (`>= 0`) must
        /// include "rise".
        @Test(arguments: configs(snippetLength: 8))
        func snippetBeforeExtendsToWordBoundary(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "alice", options: .init(caseSensitive: true))

            let match = try #require(results.first { $0.href.string == "EPUB/chapter3.xhtml" })
            #expect(match.text.before == "rise greeted ")
        }

        /// When a space falls at exactly `snippetLength` chars after the match,
        /// the after snippet must extend past it to the next word boundary.
        ///
        /// chapter3: "rise greeted alice who likes wonderland very much."
        /// With snippetLength=4, position 5 from "alice" end is the space after
        /// "who" — a hard-truncating guard stops there, producing " who".
        /// The correct guard must extend to include "likes".
        @Test(arguments: configs(snippetLength: 4))
        func snippetAfterExtendsToWordBoundary(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "alice", options: .init(caseSensitive: true))

            let match = try #require(results.first { $0.href.string == "EPUB/chapter3.xhtml" })
            #expect(match.text.after == " who likes")
        }

        /// After-snippet context should extend into subsequent elements of the
        /// same resource when the match ends near an element boundary.
        @Test(arguments: configs())
        func crossElementSnippetAfterHasContext(config: SearchServiceTestConfig) async throws {
            guard config.supportsCrossElementSearch else { return }
            let pub = try await openPublication(.reflowable, config: config)
            // "lovely" is near the end of chapter1's first paragraph
            // ("...The café was lovely."). After the match only "." remains in
            // that element; the lookahead should extend `after` into the
            // subsequent <p>The quick</p><p>brown fox.</p> elements.
            let results = try await search(pub, query: "lovely")

            let first = try #require(results.first { $0.href.string == "EPUB/chapter1.xhtml" })
            #expect(first.text.after == ". The quick brown fox.")
        }

        /// The window-fill lookahead loop must skip (not stop at) non-text
        /// elements such as `<img>`. A match whose after-snippet requires text
        /// that follows a non-text element within the same resource must
        /// include that text.
        @Test(arguments: configs())
        func snippetAfterSkipsNonTextElementInLookahead(config: SearchServiceTestConfig) async throws {
            guard config.supportsCrossElementSearch else { return }
            let pub = try await openPublication(.reflowable, config: config)
            // chapter1: "Alice went to wonderland. The café was lovely." <img> "The quick" "brown fox."
            // "lovely." ends at the very last character of the first paragraph,
            // so matchEnd == windowTextCount when the <img> stops the lookahead
            // loop, producing after = nil instead of the text that follows.
            let results = try await search(pub, query: "lovely.", options: .init(caseSensitive: true))

            let match = try #require(results.first { $0.href.string == "EPUB/chapter1.xhtml" })
            #expect(match.text.after == "The quick brown fox.")
        }

        /// Non-text elements read into the lookahead buffer during a previous
        /// resource's budget loop remain in the buffer after the window is
        /// reset at a resource boundary. They sit at the front of the buffer
        /// when the first element of the new resource is processed, causing the
        /// window-fill loop to stop immediately — the same break-on-non-text
        /// bug, but triggered by a stale element rather than a freshly-read
        /// one.
        @Test(arguments: configs())
        func snippetAfterAtResourceBoundarySkipsStaleNonTextElement(config: SearchServiceTestConfig) async throws {
            guard config.supportsCrossElementSearch else { return }
            let pub = try await openPublication(.reflowable, config: config)
            // chapter2: "ALICE found a naïve cat on 2024-01-15." <audio> "The sun"
            // The <audio> element is read into lookaheadBuffer during
            // chapter1's budget-loop phase and is still there after the
            // resource-boundary reset. "2024-01-15." ends at the last character
            // of the first text element, so matchEnd == windowTextCount when
            // the stale <audio> stops the window-fill loop, producing
            // after = nil instead of "The sun" from the next text element.
            let results = try await search(pub, query: "2024-01-15.")

            let match = try #require(results.first { $0.href.string == "EPUB/chapter2.xhtml" })
            #expect(match.text.after == "The sun")
        }
    }

    struct ResultCount {
        /// `resultCount` on the iterator should reflect all results collected
        /// so far and reach the total after exhaustion.
        @Test(arguments: configs())
        func resultCountIncreasesPerBatch(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            // "alice" (case-insensitive) appears in chapter1, chapter2,
            // chapter3 — 3 results total.
            let iterator = try await pub.search(query: "alice", options: .init(caseSensitive: false)).get()
            #expect(iterator.resultCount == 0)
            var total = 0
            while let batch = try await iterator.next().get() {
                total += batch.locators.count
                #expect(iterator.resultCount == total)
            }
            #expect(total == 3)
        }
    }

    struct InvisibleElements {
        /// `img` `alt` attributes are not part of text content, so they are
        ///  never searchable.
        @Test(arguments: configs())
        func imgAltNotSearchable(config: SearchServiceTestConfig) async throws {
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "invisible alt text")
            #expect(results.isEmpty)
        }

        /// Fallback content (`<audio>…</audio>`) should not be searchable.
        @Test(arguments: configs())
        func fallbackContentNotSearchable(config: SearchServiceTestConfig) async throws {
            guard config.ignoresFallbackContent else { return }
            let pub = try await openPublication(.reflowable, config: config)
            let results = try await search(pub, query: "audio fallback text")
            #expect(results.isEmpty)
        }
    }
}

// MARK: - Helpers

private enum Fixture: String {
    case reflowable = "search-reflowable.epub"
    case fxl = "search-fxl.epub"
}

private func openPublication(_ fixture: Fixture, config: SearchServiceTestConfig) async throws -> Publication {
    let url = Fixtures(path: "Search").url(for: fixture.rawValue)

    let container = try await ZIPArchiveOpener().open(
        resource: FileResource(file: url),
        format: Format(specifications: .zip, .epub, mediaType: .epub, fileExtension: "epub")
    ).get()

    var builder = try await EPUBParser().parse(asset: .container(container), warnings: nil).get()
    await builder.apply { _, _, services in
        services.setSearchServiceFactory(config.serviceFactory)
    }
    return builder.build()
}

/// Collects all search results from a publication into a flat array, in reading
/// order.
private func search(
    _ publication: Publication,
    query: String,
    options: SearchOptions? = nil
) async throws -> [Locator] {
    let iterator = try await publication.search(query: query, options: options).get()

    var locators: [Locator] = []
    while let page = try await iterator.next().get() {
        locators.append(contentsOf: page.locators)
    }
    return locators
}
