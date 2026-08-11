//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import SwiftSoup
import Testing

/// Tests for the accessible name and description computation
/// (`HTMLAccessibilityProperties`), through the HTML content iterator.
///
/// The cases are read from the `accname` sample, generated from
/// `/scripts/accname-sample/cases.toml`. That manifest also drives the jest
/// parity suite in
/// `/Sources/Navigator/EPUB/Scripts/test/accname-sample.test.ts`, so the two
/// implementations are asserted against a single source of truth.
///
/// Each case states its expected values in prose *and* as `data-expected-*`
/// attributes on the element under test.
/// `python3 scripts/accname-sample/generate.py` regenerates these fixtures,
/// along with an EPUB you can open in a reader to check the same cases by hand.
struct AccnameSampleTests {
    @Test(arguments: AccnameSample.cases)
    func computesTheExpectedProperties(testCase: AccnameSample.Case) async throws {
        let computed = try await AccnameSample.computedProperties()
        let actual = try #require(
            computed[testCase.id],
            "the content iterator did not emit an element for this case"
        )
        #expect(actual.name == testCase.expectedName)
        #expect(actual.description == testCase.expectedDescription)
        #expect(actual.extendedDescriptions == testCase.expectedExtendedDescriptions)
    }

    /// Catches subject elements the iterator silently drops, which would
    /// otherwise make the per-case tests vacuous.
    @Test func everyCaseIsReachedByTheIterator() async throws {
        let computed = try await AccnameSample.computedProperties()
        let missing = AccnameSample.cases
            .map(\.id)
            .filter { computed[$0] == nil }
        #expect(missing.isEmpty, "cases missing from the iterator output: \(missing)")
    }
}

// MARK: - Sample

/// Reads the `accname` sample once and exposes both the expected values (parsed
/// out of the generated markup) and the computed ones (collected from the
/// content iterator).
enum AccnameSample {
    /// A single case of the sample, matched to an iterator element by id.
    struct Case: Sendable, CustomStringConvertible {
        /// Name of the generated document holding the case.
        let document: String
        /// Value of the `data-case` attribute, also the element's `id` minus
        /// the `case-` prefix.
        let id: String
        let expectedName: String?
        let expectedDescription: String?
        /// Expected extended description links, with hrefs already resolved
        /// against the document.
        let expectedExtendedDescriptions: [Link]

        var description: String {
            "\(document) · \(id)"
        }
    }

    struct Properties: Sendable {
        let name: String?
        let description: String?
        let extendedDescriptions: [Link]
    }

    private static let fixtures = Fixtures(path: "Publication/Services/Content")

    /// The documents of the sample, discovered rather than listed, so that
    /// adding a resource to the manifest needs no change here.
    private static var documents: [String] {
        get throws {
            try FileManager.default
                .contentsOfDirectory(atPath: fixtures.url(for: "accname").path)
                .filter { $0.hasSuffix(".xhtml") }
                .sorted()
        }
    }

    private static func markup(of document: String) throws -> String {
        try String(contentsOf: fixtures.url(for: "accname/\(document)").url, encoding: .utf8)
    }

    /// Every case the harness must assert, parsed out of the generated markup.
    ///
    /// Cases flagged `data-test-skipped` describe rules that are not
    /// implemented yet and are excluded here, exactly as in the jest suite.
    static let cases: [Case] = {
        do {
            return try documents.flatMap { (document: String) -> [Case] in
                try SwiftSoup.parse(markup(of: document))
                    .select("[data-case]:not([data-test-skipped])")
                    .map { element in
                        try Case(
                            document: document,
                            id: element.attr("data-case"),
                            expectedName: element.hasAttr("data-expected-name")
                                ? element.attr("data-expected-name") : nil,
                            expectedDescription: element.hasAttr("data-expected-description")
                                ? element.attr("data-expected-description") : nil,
                            expectedExtendedDescriptions: expectedExtendedDescriptions(
                                json: element.attr("data-expected-extended-descriptions"),
                                document: document
                            )
                        )
                    }
            }
        } catch {
            fatalError("Could not read the accname sample cases: \(error)")
        }
    }()

    /// Parses the `data-expected-extended-descriptions` JSON array and
    /// resolves its document-relative hrefs against the document, matching
    /// what the iterator computes.
    private static func expectedExtendedDescriptions(json: String, document: String) throws -> [Link] {
        guard !json.isEmpty else {
            return []
        }
        guard
            let entries = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]],
            let base = AnyURL(string: document)
        else {
            fatalError("Malformed data-expected-extended-descriptions in \(document): \(json)")
        }
        return entries.map { entry in
            guard
                let href = entry["href"] as? String,
                let url = AnyURL(string: href)
            else {
                fatalError("Malformed data-expected-extended-descriptions in \(document): \(json)")
            }
            return Link(
                href: (base.resolve(url) ?? url).string,
                title: entry["title"] as? String
            )
        }
    }

    /// Iterates every document once and keys the computed properties by case id.
    ///
    /// `CSSSelectorGenerator` returns `#<id>` verbatim for an element carrying
    /// an id, so every subject element lands under `#case-<id>`. Decoy elements
    /// inside a case have no id, get a positional selector, and are ignored.
    private static let loading = Task<[String: Properties], Error> {
        var properties: [String: Properties] = [:]
        for document in try documents {
            let iterator = try HTMLResourceContentIterator(
                resource: DataResource(string: markup(of: document)),
                totalProgressionRange: { nil },
                locator: Locator(href: document, mediaType: .xhtml)
            )

            while let element = try await iterator.next() {
                guard
                    let selector = element.locator.locations["cssSelector"]?.string,
                    selector.hasPrefix("#case-")
                else {
                    continue
                }
                properties[String(selector.dropFirst("#case-".count))] = Properties(
                    name: element.accessibleName,
                    description: element.accessibleDescription,
                    extendedDescriptions: element.extendedDescriptions
                )
            }
        }
        return properties
    }

    static func computedProperties() async throws -> [String: Properties] {
        try await loading.value
    }
}
