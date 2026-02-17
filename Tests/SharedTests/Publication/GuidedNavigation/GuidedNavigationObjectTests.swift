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
            #expect(try sut == GuidedNavigationObject(
                refs: .init(text: #require(AnyURL(string: "chapter1.html")))
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
                "role": ["chapter", "heading"],
                "level": 2,
                "children": [
                    ["textref": "child.html"],
                ],
                "description": ["textref": "desc.html"],
            ])

            #expect(try sut == GuidedNavigationObject(
                id: "obj1",
                refs: .init(
                    text: #require(AnyURL(string: "chapter1.html")),
                    img: #require(AnyURL(string: "page1.jpg")),
                    audio: #require(AnyURL(string: "audio.mp3#t=0,20")),
                    video: #require(AnyURL(string: "video.mp4#t=10,30"))
                ),
                text: .init(plain: "Hello", ssml: "<speak>Hello</speak>", language: Language(code: .bcp47("en"))),
                role: [.chapter, .heading],
                level: .two,
                description: .init(refs: .init(text: #require(AnyURL(string: "desc.html")))),
                children: [
                    #require(GuidedNavigationObject(refs: .init(text: #require(AnyURL(string: "child.html"))))),
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

        @Test("level in valid range 1-6 is accepted")
        func levelValid() throws {
            let sut = try GuidedNavigationObject(json: [
                "textref": "c.html",
                "level": 3,
            ])
            #expect(sut?.level == .three)
        }

        @Test("level out of range is silently ignored")
        func levelOutOfRange() throws {
            let sut0 = try GuidedNavigationObject(json: [
                "textref": "c.html",
                "level": 0,
            ])
            #expect(sut0?.level == nil)

            let sut7 = try GuidedNavigationObject(json: [
                "textref": "c.html",
                "level": 7,
            ])
            #expect(sut7?.level == nil)
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
            #expect(sut?.role == [.chapter, GuidedNavigationObject.Role("custom-role")])
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
            #expect(try sut == GuidedNavigationObject.Refs(
                text: #require(AnyURL(string: "chapter.html")),
                img: #require(AnyURL(string: "page.jpg")),
                audio: #require(AnyURL(string: "track.mp3")),
                video: #require(AnyURL(string: "clip.mp4"))
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
            #expect(try sut == GuidedNavigationObject.Description(
                refs: .init(img: #require(AnyURL(string: "desc.jpg")))
            ))
        }

        @Test("returns nil when empty")
        func nilWhenEmpty() throws {
            #expect(throws: JSONError.self) {
                try GuidedNavigationObject.Description(json: [
                    "id": "nothing",
                ])
            }
        }
    }

    @Suite("Text") struct TextTests {
        @Test("returns nil when both plain and ssml are nil")
        func nilWhenEmpty() {
            let text = GuidedNavigationObject.Text()
            #expect(text == nil)
        }
    }

    @Suite("Level") struct LevelTests {
        @Test("all valid levels")
        func allLevels() {
            #expect(GuidedNavigationObject.Level(rawValue: 1) == .one)
            #expect(GuidedNavigationObject.Level(rawValue: 2) == .two)
            #expect(GuidedNavigationObject.Level(rawValue: 3) == .three)
            #expect(GuidedNavigationObject.Level(rawValue: 4) == .four)
            #expect(GuidedNavigationObject.Level(rawValue: 5) == .five)
            #expect(GuidedNavigationObject.Level(rawValue: 6) == .six)
        }

        @Test("invalid raw values return nil")
        func invalidValues() {
            #expect(GuidedNavigationObject.Level(rawValue: 0) == nil)
            #expect(GuidedNavigationObject.Level(rawValue: 7) == nil)
        }
    }
}
