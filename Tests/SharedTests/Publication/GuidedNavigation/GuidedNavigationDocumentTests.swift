//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum GuidedNavigationDocumentTests {
    struct Parsing {
        @Test("minimal JSON with just guided")
        func minimalJSON() throws {
            let sut = try GuidedNavigationDocument(json: [
                "guided": [
                    ["textref": "chapter1.html"],
                ],
            ])

            #expect(sut == GuidedNavigationDocument(
                guided: [
                    GuidedNavigationObject(refs: .init(text: WebReference(href: AnyURL(string: "chapter1.html")!)))!,
                ]
            ))
        }

        @Test("full JSON with guided")
        func fullJSON() throws {
            let sut = try GuidedNavigationDocument(json: [
                "guided": [
                    ["textref": "chapter1.html"],
                    ["audioref": "track.mp3"],
                ],
            ])

            #expect(sut?.guided.count == 2)
        }

        @Test("missing guided throws")
        func missingGuided() throws {
            #expect(throws: JSONError.self) {
                try GuidedNavigationDocument(json: [:])
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
