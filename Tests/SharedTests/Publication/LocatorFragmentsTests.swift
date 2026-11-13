//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum LocatorFragmentsTests {
    struct Parsing {
        @Test("a percent-encoded fragment is kept as is", arguments: [
            "page=2",
            "caf%C3%A9",
            "t=10&track=a%26b",
            ":~:text=in%20asking-,riddles",
        ])
        func percentEncoded(fragment: String) throws {
            #expect(try parseFragments([fragment]).map(\.rawValue) == [fragment])
        }

        @Test("a fragment which is not percent-encoded is encoded as a whole", arguments: [
            ("café", "caf%C3%A9"),
            ("my id", "my%20id"),
            ("100%", "100%25"),
            // An existing escape is encoded like any other character.
            ("a%20b c", "a%2520b%20c"),
        ])
        func notPercentEncoded(fragment: String, expected: String) throws {
            #expect(try parseFragments([fragment]).map(\.rawValue) == [expected])
        }

        @Test("a fragment valid in both forms is read as percent-encoded")
        func ambiguous() throws {
            // A fragment written `a%20b` by a previous version, for the ID
            // `a%20b`, is read as the ID `a b`.
            let fragments = try parseFragments(["a%20b"])
            #expect(fragments.map(\.rawValue) == ["a%20b"])
            #expect(fragments.map(\.percentDecoded) == ["a b"])
        }

        @Test("one leading # is removed", arguments: [
            ("#page=2", "page=2"),
            ("#caf%C3%A9", "caf%C3%A9"),
            ("#café", "caf%C3%A9"),
            // Only the first one is a prefix.
            ("##id", "%23id"),
        ])
        func hashPrefix(fragment: String, expected: String) throws {
            #expect(try parseFragments([fragment]).map(\.rawValue) == [expected])
        }

        @Test("an empty fragment is dropped with a warning", arguments: ["", "#"])
        func empty(fragment: String) throws {
            let warnings = ListWarningLogger()
            let fragments = try parseFragments(["page=2", fragment, "café"], warnings: warnings)

            #expect(fragments.map(\.rawValue) == ["page=2", "caf%C3%A9"])
            #expect(warnings.warnings.count == 1)
        }

        @Test("the legacy fragment key is read like a fragment and comes last")
        func legacyFragmentKey() throws {
            let locations = try #require(try Locator.Locations(json: [
                "fragments": ["page=2"],
                "fragment": "café",
            ] as JSONValue))
            #expect(locations.fragments.map(\.rawValue) == ["page=2", "caf%C3%A9"])
        }

        @Test("Locator(legacyJSONString:) reads percent-encoded and legacy fragments")
        func locatorLegacyJSONString() throws {
            let locator = try #require(try Locator(legacyJSONString: """
            {"href": "chap1.html", "type": "text/html", "locations": {"fragments": ["caf%C3%A9", "my id", "#page=2", ""]}}
            """))
            #expect(locator.locations.fragments.map(\.rawValue) == ["caf%C3%A9", "my%20id", "page=2"])
        }
    }

    struct Serializing {
        @Test("the fragments are written percent-encoded")
        func percentEncoded() {
            let locations = Locator.Locations(fragments: ["page=2", "caf%C3%A9", "t=10&track=a%26b"])
            #expect(locations.jsonObject == ["fragments": ["page=2", "caf%C3%A9", "t=10&track=a%26b"]])
        }
    }
}

// MARK: - Helpers

/// Returns the fragments of a `Locator.Locations` parsed from a JSON object
/// holding the given `fragments` strings.
private func parseFragments(_ fragments: [String], warnings: WarningLogger? = nil) throws -> [URLFragment] {
    try #require(try Locator.Locations(json: ["fragments": fragments.jsonValue] as JSONValue, warnings: warnings)).fragments
}
