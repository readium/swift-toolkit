//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

@Suite enum GuidedNavigationDocumentTests {
    @Suite("Parsing") struct Parsing {
        @Test("minimal JSON with just guided")
        func minimalJSON() throws {
            let sut = try GuidedNavigationDocument(json: [
                "guided": [
                    ["textref": "chapter1.html"],
                ],
            ])

            #expect(try sut == GuidedNavigationDocument(
                guided: [
                    #require(GuidedNavigationObject(refs: .init(text: #require(AnyURL(string: "chapter1.html"))))),
                ]
            ))
        }

        @Test("full JSON with links and guided")
        func fullJSON() throws {
            let sut = try GuidedNavigationDocument(json: [
                "links": [
                    ["href": "https://example.com/manifest.json", "type": "application/webpub+json", "rel": "self"],
                ],
                "guided": [
                    ["textref": "chapter1.html"],
                    ["audioref": "track.mp3"],
                ],
            ])

            #expect(sut?.guided.count == 2)
            #expect(sut?.links.count == 1)
        }

        @Test("missing guided throws")
        func missingGuided() throws {
            #expect(throws: JSONError.self) {
                try GuidedNavigationDocument(json: [
                    "links": [],
                ])
            }
        }

        @Test("empty guided array throws")
        func emptyGuided() throws {
            #expect(throws: JSONError.self) {
                try GuidedNavigationDocument(json: [
                    "guided": [],
                ])
            }
        }

        @Test("nil JSON returns nil")
        func nilJSON() throws {
            let sut = try GuidedNavigationDocument(json: nil)
            #expect(sut == nil)
        }
    }
}
