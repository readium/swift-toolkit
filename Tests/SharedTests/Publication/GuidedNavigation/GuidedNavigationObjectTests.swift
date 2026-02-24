//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

@Suite enum GuidedNavigationObjectTests {
    @Suite("Parsing") struct Parsing {
        @Test("minimal JSON with only textref")
        func minimalTextref() throws {
            let sut = try GuidedNavigationObject(json: [
                "textref": "chapter1.html",
            ])
            #expect(sut == GuidedNavigationObject(
                refs: .init(text: AnyURL(string: "chapter1.html"))
            ))
        }

        @Test("full JSON with all properties")
        func fullJSON() throws {
            let sut = try GuidedNavigationObject(json: [
                "id": "obj1",
                "audioref": "audio.mp3#t=0,20",
                "imgref": "page1.jpg",
                "textref": "chapter1.html",
                "videoref": "video.mp4#t=10,30",
                "text": ["plain": "Hello", "ssml": "<speak>Hello</speak>", "language": "en"],
                "role": ["chapter", "heading2"],
                "children": [
                    ["textref": "child.html"],
                ],
                "description": ["textref": "desc.html"],
            ])

            #expect(try sut == GuidedNavigationObject(
                id: "obj1",
                refs: .init(
                    text: AnyURL(string: "chapter1.html"),
                    img: AnyURL(string: "page1.jpg"),
                    audio: AnyURL(string: "audio.mp3#t=0,20"),
                    video: AnyURL(string: "video.mp4#t=10,30")
                ),
                text: .init(plain: "Hello", ssml: "<speak>Hello</speak>", language: Language(code: .bcp47("en"))),
                roles: [.chapter, .heading2],
                description: .init(refs: .init(text: AnyURL(string: "desc.html"))),
                children: [
                    #require(GuidedNavigationObject(refs: .init(text: AnyURL(string: "child.html")))),
                ]
            ))
        }

        @Test("text as bare string normalizes to Text(plain:)")
        func textBareString() throws {
            let sut = try GuidedNavigationObject(json: [
                "text": "Hello world",
            ])
            #expect(sut?.text == GuidedNavigationObject.Text(plain: "Hello world"))
        }

        @Test("text as object with plain, ssml, and language")
        func textObject() throws {
            let sut = try GuidedNavigationObject(json: [
                "text": ["plain": "Hello", "ssml": "<speak>Hello</speak>", "language": "en"],
            ])
            #expect(sut?.text == GuidedNavigationObject.Text(
                plain: "Hello",
                ssml: "<speak>Hello</speak>",
                language: Language(code: .bcp47("en"))
            ))
        }

        @Test("requires at least one ref, text, or children")
        func requiresContent() throws {
            #expect(throws: JSONError.self) {
                try GuidedNavigationObject(json: [
                    "id": "empty",
                    "role": ["chapter"],
                ])
            }
        }

        @Test("nested children parse correctly")
        func nestedChildren() throws {
            let sut = try GuidedNavigationObject(json: [
                "children": [
                    [
                        "textref": "a.html",
                        "children": [
                            ["textref": "b.html"],
                        ],
                    ],
                ],
            ])

            #expect(sut?.children.count == 1)
            #expect(sut?.children.first?.children.count == 1)
            #expect(sut?.children.first?.children.first?.refs?.text == AnyURL(string: "b.html")!)
        }

        @Test("recursive description parses correctly")
        func recursiveDescription() throws {
            let sut = try GuidedNavigationObject(json: [
                "textref": "main.html",
                "description": [
                    "text": "A description",
                ],
            ])

            #expect(sut?.description == GuidedNavigationObject.Description(
                text: .init(plain: "A description")
            ))
        }

        @Test("unknown roles are preserved")
        func unknownRoles() throws {
            let sut = try GuidedNavigationObject(json: [
                "textref": "c.html",
                "role": ["chapter", "custom-role"],
            ])
            #expect(sut?.roles == [.chapter, ContentRole("custom-role")])
        }

        @Test("nil JSON returns nil")
        func nilJSON() throws {
            let sut = try GuidedNavigationObject(json: nil)
            #expect(sut == nil)
        }
    }

    @Suite("Refs") struct RefsTests {
        @Test("parses all ref types from JSON")
        func parsesAllRefs() throws {
            let sut = try GuidedNavigationObject.Refs(json: [
                "textref": "chapter.html",
                "imgref": "page.jpg",
                "audioref": "track.mp3",
                "videoref": "clip.mp4",
            ])
            #expect(sut == GuidedNavigationObject.Refs(
                text: AnyURL(string: "chapter.html"),
                img: AnyURL(string: "page.jpg"),
                audio: AnyURL(string: "track.mp3"),
                video: AnyURL(string: "clip.mp4")
            ))
        }

        @Test("returns nil when no refs present")
        func nilWhenNoRefs() throws {
            let sut = try GuidedNavigationObject.Refs(json: [
                "id": "test",
            ])
            #expect(sut == nil)
        }

        @Test("preserves URI fragments")
        func preservesFragments() throws {
            let sut = try GuidedNavigationObject.Refs(json: [
                "audioref": "audio.mp3#t=0,20",
            ])
            #expect(sut?.audio == AnyURL(string: "audio.mp3#t=0,20")!)
        }
    }

    @Suite("Description") struct DescriptionTests {
        @Test("parses description with text")
        func withText() throws {
            let sut = try GuidedNavigationObject.Description(json: [
                "text": "A description",
            ])
            #expect(sut == GuidedNavigationObject.Description(
                text: .init(plain: "A description")
            ))
        }

        @Test("parses description with refs")
        func withRefs() throws {
            let sut = try GuidedNavigationObject.Description(json: [
                "imgref": "desc.jpg",
            ])
            #expect(sut == GuidedNavigationObject.Description(
                refs: .init(img: AnyURL(string: "desc.jpg"))
            ))
        }

        @Test("throws when empty")
        func throwsWhenEmpty() throws {
            #expect(throws: JSONError.self) {
                try GuidedNavigationObject.Description(json: [
                    "id": "nothing",
                ])
            }
        }
    }

    @Suite("Text") struct TextTests {
        @Test("returns nil when both plain and ssml are nil")
        func nilWhenBothNil() {
            let text = GuidedNavigationObject.Text()
            #expect(text == nil)
        }

        @Test("returns nil when plain is empty and ssml is nil")
        func nilWhenPlainEmpty() {
            let text = GuidedNavigationObject.Text(plain: "")
            #expect(text == nil)
        }

        @Test("returns nil when ssml is empty and plain is nil")
        func nilWhenSsmlEmpty() {
            let text = GuidedNavigationObject.Text(ssml: "")
            #expect(text == nil)
        }

        @Test("returns nil when both plain and ssml are empty strings")
        func nilWhenBothEmpty() {
            let text = GuidedNavigationObject.Text(plain: "", ssml: "")
            #expect(text == nil)
        }

        @Test("succeeds when only plain is non-empty")
        func succeedsWithPlainOnly() {
            let text = GuidedNavigationObject.Text(plain: "Hello")
            #expect(text != nil)
            #expect(text?.plain == "Hello")
        }

        @Test("succeeds when only ssml is non-empty")
        func succeedsWithSsmlOnly() {
            let text = GuidedNavigationObject.Text(ssml: "<speak>Hi</speak>")
            #expect(text != nil)
            #expect(text?.ssml == "<speak>Hi</speak>")
        }

        @Test("JSON object with empty plain and ssml returns nil")
        func jsonObjectEmptyStringsReturnsNil() throws {
            let sut = try GuidedNavigationObject.Text(json: ["plain": "", "ssml": ""])
            #expect(sut == nil)
        }
    }
}
