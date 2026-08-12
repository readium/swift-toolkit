//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct HTMLResourceContentIteratorTests {
    @Test func iterateFromStartToFinish() async throws {
        let iter = makeIterator(sampleHTML)
        for expected in sampleElements {
            let result = try await iter.next()
            #expect(result?.equatable() == expected)
        }
        let result = try await iter.next()
        #expect(result == nil)
    }

    @Test func previousIsNullFromTheBeginning() async throws {
        let iter = makeIterator(sampleHTML)
        let result = try await iter.previous()
        #expect(result == nil)
    }

    @Test func nextReturnsTheFirstElementFromTheBeginning() async throws {
        let iter = makeIterator(sampleHTML)
        let result = try await iter.next()
        #expect(result?.equatable() == sampleElements[0])
    }

    @Test func nextThenPreviousReturnsNull() async throws {
        let iter = makeIterator(sampleHTML)
        let first = try await iter.next()
        #expect(first?.equatable() == sampleElements[0])
        let back = try await iter.previous()
        #expect(back == nil)
    }

    @Test func nextTwiceThenPreviousReturnsTheFirstElement() async throws {
        let iter = makeIterator(sampleHTML)
        let first = try await iter.next()
        #expect(first?.equatable() == sampleElements[0])
        let second = try await iter.next()
        #expect(second?.equatable() == sampleElements[1])
        let back = try await iter.previous()
        #expect(back?.equatable() == sampleElements[0])
    }

    @Test(arguments: zip(
        [0.5, 0.21, 0.81],
        [sampleElements[2], sampleElements[1], sampleElements[4]]
    ))
    func startingFromProgression(progression: Double, expected: AnyEquatableContentElement) async throws {
        let result = try await makeIterator(sampleHTML, start: makeLocator(progression: progression)).next()
        #expect(result?.equatable() == expected)
    }

    @Test func startingFromCSSSelector() async throws {
        let iter = makeIterator(sampleHTML, start: makeLocator(selector: "#pgepubid00498 > p:nth-child(3)"))
        for expected in sampleElements[2...] {
            let result = try await iter.next()
            #expect(result?.equatable() == expected)
        }
        let result = try await iter.next()
        #expect(result == nil)
    }

    @Test func callingPreviousWhenStartingFromCSSSelector() async throws {
        let iter = makeIterator(sampleHTML, start: makeLocator(selector: "#pgepubid00498 > p:nth-child(3)"))
        let result = try await iter.previous()
        #expect(result?.equatable() == sampleElements[1])
    }

    @Test func startingFromCSSSelectorToBlockElementContainingInlineElement() async throws {
        let html = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr">
        <body>
            <p>Tout au loin sur la chaussée, aussi loin qu'on pouvait voir</p>
            <p>Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient <span>[...]</span> On buvait de la bière sucrée.</p>
        </body>
        </html>
        """

        let iter = makeIterator(html, start: makeLocator(selector: ":root > :nth-child(1) > :nth-child(2)"))

        let expected = TextContentElement(
            locator: makeLocator(
                progression: 0.5,
                selector: "html > body > p:nth-child(2)",
                before: "oin sur la chaussée, aussi loin qu'on pouvait voir",
                highlight: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée."
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: makeLocator(
                        progression: 0.5,
                        selector: "html > body > p:nth-child(2)",
                        before: "oin sur la chaussée, aussi loin qu'on pouvait voir",
                        highlight: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée."
                    ),
                    text: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée.",
                    attributes: [ContentAttribute(key: .language, value: Language("fr"))]
                ),
            ]
        )

        let result = try await iter.next()
        #expect(result?.equatable() == expected.equatable())
    }

    @Test func startingFromCSSSelectorUsingRootSelector() async throws {
        let html = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr">
        <head></head>
        <body>
            <p>Tout au loin sur la chaussée, aussi loin qu'on pouvait voir</p>
            <p>Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient <span>[...]</span> On buvait de la bière sucrée.</p>
        </body>
        </html>
        """

        let iter = makeIterator(html, start: makeLocator(selector: ":root > :nth-child(2) > :nth-child(2)"))

        let expected = TextContentElement(
            locator: makeLocator(
                progression: 0.5,
                selector: "html > body > p:nth-child(2)",
                before: "oin sur la chaussée, aussi loin qu'on pouvait voir",
                highlight: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée."
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: makeLocator(
                        progression: 0.5,
                        selector: "html > body > p:nth-child(2)",
                        before: "oin sur la chaussée, aussi loin qu'on pouvait voir",
                        highlight: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée."
                    ),
                    text: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée.",
                    attributes: [ContentAttribute(key: .language, value: Language("fr"))]
                ),
            ]
        )

        let result = try await iter.next()
        #expect(result?.equatable() == expected.equatable())
    }

    @Test func iteratingOverImageElements() async throws {
        let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <img src="image.png"/>
                <img src="../cover.jpg" alt="Accessibility description" />
            </body>
            </html>
        """

        let expectedElements: [AnyEquatableContentElement] = [
            ImageContentElement(
                locator: makeLocator(progression: 0.0, selector: "html > body > img:nth-child(1)"),
                embeddedLink: Link(href: "dir/image.png"),
                caption: nil,
                attributes: []
            ).equatable(),
            ImageContentElement(
                locator: makeLocator(progression: 0.5, selector: "html > body > img:nth-child(2)"),
                embeddedLink: Link(href: "cover.jpg"),
                caption: nil,
                attributes: [ContentAttribute(key: .accessibleName, value: "Accessibility description")]
            ).equatable(),
        ]

        let iter = makeIterator(html)
        for expected in expectedElements {
            let result = try await iter.next()
            #expect(result?.equatable() == expected)
        }
        let result = try await iter.next()
        #expect(result == nil)
    }

    @Test func iteratingOverAudioElements() async throws {
        let html = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
            <audio src="audio.mp3" />
            <audio>
                <source src="audio.mp3" type="audio/mpeg" />
                <source src="audio.ogg" type="audio/ogg" />
            </audio>
        </body>
        </html>
        """

        let expectedElements: [AnyEquatableContentElement] = [
            AudioContentElement(
                locator: makeLocator(progression: 0.0, selector: "html > body > audio:nth-child(1)"),
                embeddedLink: Link(href: "dir/audio.mp3"),
                attributes: []
            ).equatable(),
            AudioContentElement(
                locator: makeLocator(progression: 0.5, selector: "html > body > audio:nth-child(2)"),
                embeddedLink: Link(
                    href: "dir/audio.mp3",
                    mediaType: .mp3,
                    alternates: [Link(href: "dir/audio.ogg", mediaType: .ogg)]
                ),
                attributes: []
            ).equatable(),
        ]

        let iter = makeIterator(html)
        for expected in expectedElements {
            let result = try await iter.next()
            #expect(result?.equatable() == expected)
        }
        let result = try await iter.next()
        #expect(result == nil)
    }

    @Test func iteratingOverVideoElements() async throws {
        let html = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
            <video src="video.mp4" />
            <video>
                <source src="video.mp4" type="video/mp4" />
                <source src="video.m4v" type="video/x-m4v" />
            </video>
        </body>
        </html>
        """

        let expectedElements: [AnyEquatableContentElement] = [
            VideoContentElement(
                locator: makeLocator(progression: 0.0, selector: "html > body > video:nth-child(1)"),
                embeddedLink: Link(href: "dir/video.mp4"),
                attributes: []
            ).equatable(),
            VideoContentElement(
                locator: makeLocator(progression: 0.5, selector: "html > body > video:nth-child(2)"),
                embeddedLink: Link(
                    href: "dir/video.mp4",
                    mediaType: MediaType("video/mp4"),
                    alternates: [Link(href: "dir/video.m4v", mediaType: MediaType("video/x-m4v"))]
                ),
                attributes: []
            ).equatable(),
        ]

        let iter = makeIterator(html)
        for expected in expectedElements {
            let result = try await iter.next()
            #expect(result?.equatable() == expected)
        }
        let result = try await iter.next()
        #expect(result == nil)
    }

    /// What the caption rules themselves compute is asserted by
    /// `AccessibilityPropertiesSampleTests`, from the shared case manifest in
    /// `Tests/Samples/accessibility-properties/cases.toml`. Only what the
    /// manifest cannot express — the structure the iterator emits around a
    /// figure — lives here.
    struct Figures {
        @Test func theFigcaptionIsAlsoEmittedAsATextElement() async throws {
            let elements = try await allElements("""
            <figure><img src="a.jpg" alt="Alt text"/><figcaption>The caption</figcaption></figure>
            """)

            #expect(elements.count == 2)
            let image = try #require(elements[0] as? ImageContentElement)
            #expect(image.caption == "The caption")
            #expect(image.text == "Alt text")

            let text = try #require(elements[1] as? TextContentElement)
            #expect(text.text == "The caption")
        }

        @Test func everyImageOfAFigureIsEmitted() async throws {
            let elements = try await allElements("""
            <figure>
                <img src="chart.png" alt="Revenue chart"/>
                <figcaption>Source: <img src="logo.png" alt="ACME"/> annual report</figcaption>
            </figure>
            """)

            // The logo wrapped by the figcaption is an element of its own,
            // emitted alongside the chart and the caption's text.
            let images = elements.compactMap { $0 as? ImageContentElement }
            #expect(images.count == 2)
        }
    }

    struct MediaAccessibilityAttributes {
        @Test func audioElementExposesAccessibilityAttributes() async throws {
            let elements = try await allElements("""
            <audio src="a.mp3" aria-label="Podcast"/>
            """)

            let audio = try #require(elements.first as? AudioContentElement)
            #expect(audio.accessibleName == "Podcast")
        }

        @Test func videoElementExposesAccessibilityAttributes() async throws {
            let elements = try await allElements("""
            <video src="v.mp4" aria-label="Movie"/>
            """)

            let video = try #require(elements.first as? VideoContentElement)
            #expect(video.accessibleName == "Movie")
        }
    }

    struct ExtendedDescriptions {
        @Test func figureLevelAriaDetailsIsIgnored() async throws {
            let elements = try await allElements("""
            <figure aria-details="chart-desc">
                <img src="a.jpg" alt="Chart"/>
            </figure>
            <aside id="chart-desc"><p>Details.</p></aside>
            """)

            let image = try #require(elements.compactMap { $0 as? ImageContentElement }.first)
            #expect(image.extendedDescriptions.isEmpty)
        }

        @Test func inlineTargetIsStillEmittedInTheContentStream() async throws {
            let elements = try await allElements("""
            <img src="a.jpg" alt="Chart" aria-details="chart-desc"/>
            <aside id="chart-desc"><p>A long description.</p></aside>
            """)

            let texts = elements.compactMap { $0 as? TextContentElement }
            #expect(texts.map(\.text) == ["A long description."])
        }
    }

    struct SVGElements {
        @Test func inlineSVGIsEmittedAsAnSVGElementAndItsSubtreeIsSkipped() async throws {
            let elements = try await allElements("""
            <p>Before</p>
            <svg><title>Chart title</title><desc>Chart description</desc><circle/></svg>
            <p>After</p>
            """)

            #expect(elements.count == 3)
            #expect((elements[0] as? TextContentElement)?.text == "Before")
            #expect((elements[2] as? TextContentElement)?.text == "After")

            let svg = try #require(elements[1] as? SVGContentElement)
            #expect(svg.svg.contains("circle"))
            #expect(svg.accessibleName == "Chart title")
            #expect(svg.accessibleDescription == "Chart description")
            #expect(svg.locator.locations.progression != nil)

            // The SVG title and description must not leak as text elements.
            let texts = elements.compactMap { ($0 as? TextContentElement)?.text }
            #expect(!texts.contains { $0.contains("Chart title") || $0.contains("Chart description") })
        }

        @Test func svgInFigureGetsCaptionFromFigcaption() async throws {
            let elements = try await allElements("""
            <figure><svg><circle/></svg><figcaption>Fig</figcaption></figure>
            """)

            let svg = try #require(elements.compactMap { $0 as? SVGContentElement }.first)
            #expect(svg.caption == "Fig")
        }

        @Test func nestedMediaInsideSVGIsNotEmitted() async throws {
            let elements = try await allElements("""
            <svg><foreignObject><img src="b.jpg" alt="Nested"/></foreignObject></svg>
            """)

            #expect(elements.count == 1)
            #expect(elements[0] is SVGContentElement)
        }

        @Test func ariaLabelledbyResolvesIntoASkippedSubtree() async throws {
            let elements = try await allElements("""
            <svg><text id="t1">Label in svg</text></svg>
            <img src="a.jpg" aria-labelledby="t1"/>
            """)

            let image = try #require(elements.compactMap { $0 as? ImageContentElement }.first)
            #expect(image.accessibleName == "Label in svg")
        }
    }

    struct ImageFallbackContent {
        @Test func imageInVideoFallbackContentIsNotEmitted() async throws {
            let elements = try await allElements("""
            <video src="v.mp4"><img src="poster.jpg" alt="Poster"/></video>
            """)

            #expect(elements.count == 1)
            #expect(elements[0] is VideoContentElement)
        }
    }

    @Test func iteratingOverElementContainingBothATextNodeAndChildElements() async throws {
        let html = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
            <ol class="decimal" id="c06-list-0001">
                <li id="c06-li-0001">Let&#39;s start at the top&#8212;the <i>source of ideas</i>.
                    <aside><div class="top hr"><hr/></div>
                    <section class="feature1">
                        <p id="c06-para-0019"><i>While almost everyone today claims to be Agile, what I&#39;ve just described is very much a <i>waterfall</i> process.</i></p>
                    </section>
                    Trailing text
                </li>
            </ol>
        </body>
        </html>
        """

        let expectedElements: [AnyEquatableContentElement] = [
            TextContentElement(
                locator: makeLocator(
                    progression: 0.0,
                    selector: "#c06-li-0001",
                    highlight: "Let's start at the top—the source of ideas."
                ),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: makeLocator(
                            progression: 0.0,
                            selector: "#c06-li-0001",
                            highlight: "Let's start at the top—the source of ideas."
                        ),
                        text: "Let's start at the top—the source of ideas.",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
            TextContentElement(
                locator: makeLocator(
                    progression: 1 / 3.0,
                    selector: "#c06-para-0019",
                    before: "start at the top—the source of ideas.\n            ",
                    highlight: "While almost everyone today claims to be Agile, what I've just described is very much a waterfall process."
                ),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: makeLocator(
                            progression: 1 / 3.0,
                            selector: "#c06-para-0019",
                            before: "start at the top—the source of ideas.\n            ",
                            highlight: "While almost everyone today claims to be Agile, what I've just described is very much a waterfall process."
                        ),
                        text: "While almost everyone today claims to be Agile, what I've just described is very much a waterfall process.",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
            TextContentElement(
                locator: makeLocator(
                    progression: 2 / 3.0,
                    selector: "#c06-li-0001 > aside",
                    before: "e just described is very much a waterfall process.\n            \n            ",
                    highlight: "Trailing text"
                ),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: makeLocator(
                            progression: 2 / 3.0,
                            selector: "#c06-li-0001 > aside",
                            before: "e just described is very much a waterfall process.\n            ",
                            highlight: "Trailing text"
                        ),
                        text: "Trailing text",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
        ]

        let iter = makeIterator(html)
        for expected in expectedElements {
            let result = try await iter.next()
            #expect(result?.equatable() == expected)
        }
        let result = try await iter.next()
        #expect(result == nil)
    }

    @Test func iteratingOverTextNodesLocatedAroundANestedBlockElement() async throws {
        let html = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
            <div id="a">begin a <div id="b">in b</div> end a</div>
            <div id="c">in c</div>
        </body>
        </html>
        """

        let expectedElements: [AnyEquatableContentElement] = [
            TextContentElement(
                locator: makeLocator(progression: 0.0, selector: "#a", highlight: "begin a"),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: makeLocator(progression: 0.0, selector: "#a", highlight: "begin a"),
                        text: "begin a",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
            TextContentElement(
                locator: makeLocator(progression: 0.25, selector: "#b", before: "begin a ", highlight: "in b"),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: makeLocator(progression: 0.25, selector: "#b", before: "begin a ", highlight: "in b"),
                        text: "in b",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
            TextContentElement(
                locator: makeLocator(progression: 0.5, selector: "#a", before: "begin a in b  ", highlight: "end a"),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: makeLocator(progression: 0.5, selector: "#a", before: "begin a in b ", highlight: "end a"),
                        text: "end a",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
            TextContentElement(
                locator: makeLocator(progression: 0.75, selector: "#c", before: "begin a in b end a", highlight: "in c"),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: makeLocator(progression: 0.75, selector: "#c", before: "begin a in b end a", highlight: "in c"),
                        text: "in c",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
        ]

        let iter = makeIterator(html)
        for expected in expectedElements {
            let result = try await iter.next()
            #expect(result?.equatable() == expected)
        }
        let result = try await iter.next()
        #expect(result == nil)
    }

    struct AudioVideoFallbackContent {
        @Test func audioWithOnlyFallbackTextProducesNoElement() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <audio>
                    <p>audio fallback text</p>
                </audio>
            </body>
            </html>
            """

            let result = try await makeIterator(html).next()
            #expect(result == nil)
        }

        @Test func audioWithSourceAndFallbackTextEmitsOnlyAudioElement() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <audio>
                    <source src="audio.mp3" type="audio/mpeg" />
                    <p>audio fallback text</p>
                </audio>
            </body>
            </html>
            """

            let iter = makeIterator(html)
            let first = try await iter.next()
            #expect(first?.equatable() == AudioContentElement(
                locator: makeLocator(progression: 0.0, selector: "html > body > audio"),
                embeddedLink: Link(href: "dir/audio.mp3", mediaType: .mp3),
                attributes: []
            ).equatable())
            let second = try await iter.next()
            #expect(second == nil)
        }

        @Test func videoWithOnlyFallbackTextProducesNoElement() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <video>
                    <p>video fallback text</p>
                </video>
            </body>
            </html>
            """

            let result = try await makeIterator(html).next()
            #expect(result == nil)
        }

        @Test func videoWithSourceAndFallbackTextEmitsOnlyVideoElement() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <video>
                    <source src="video.mp4" type="video/mp4" />
                    <p>video fallback text</p>
                </video>
            </body>
            </html>
            """

            let iter = makeIterator(html)
            let first = try await iter.next()
            #expect(first?.equatable() == VideoContentElement(
                locator: makeLocator(progression: 0.0, selector: "html > body > video"),
                embeddedLink: Link(href: "dir/video.mp4", mediaType: MediaType("video/mp4")),
                attributes: []
            ).equatable())
            let second = try await iter.next()
            #expect(second == nil)
        }
    }

    struct CSSSelectorIDOptimization {
        @Test func imageInsideNamedParentUsesParentIDInSelector() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <div id="wrap"><img src="a.png"/></div>
            </body>
            </html>
            """
            let result = try await makeIterator(html).next()
            #expect(result?.locator.locations.cssSelector == "#wrap > img")
        }

        @Test func imageWithOwnIDUsesDirectIDSelector() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <div><img id="pic" src="a.png"/></div>
            </body>
            </html>
            """
            let result = try await makeIterator(html).next()
            #expect(result?.locator.locations.cssSelector == "#pic")
        }

        @Test func textDivWithIDUsesDirectIDSelector() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <div id="txt">Hello</div>
            </body>
            </html>
            """
            let result = try await makeIterator(html).next()
            #expect(result?.locator.locations.cssSelector == "#txt")
        }
    }

    struct CSSSelectorEscaping {
        @Test func idWithSpecialCharactersIsEscaped() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <p id="foo.bar">Hello</p>
            </body>
            </html>
            """
            let result = try await makeIterator(html).next()
            #expect(result?.locator.locations.cssSelector == "#foo\\.bar")
        }

        @Test func classWithSpecialCharactersIsEscaped() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <p class="foo.bar">Hello</p>
            </body>
            </html>
            """
            let result = try await makeIterator(html).next()
            #expect(result?.locator.locations.cssSelector == "html > body > p.foo\\.bar")
        }

        @Test func multipleClassesAreSortedAlphabetically() async throws {
            let html = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <body>
                <p class="zebra apple mango">Hello</p>
            </body>
            </html>
            """
            let result = try await makeIterator(html).next()
            #expect(result?.locator.locations.cssSelector == "html > body > p.apple.mango.zebra")
        }
    }
}

// MARK: - Helpers

private let baseLocator = Locator(href: "dir/res.xhtml", mediaType: .xhtml)

private let sampleHTML = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en">
    <head>
        <title>Section IV: FAIRY STORIES—MODERN FANTASTIC TALES</title>
        <link href="css/epub.css" type="text/css" rel="stylesheet" />
    </head>
    <body>
         <section id="pgepubid00498">
             <div class="center"><span epub:type="pagebreak" title="171" id="Page_171">171</span></div>
             <h3>INTRODUCTORY</h3>

             <p>The difficulties of classification are very apparent here, and once more it must be noted that illustrative and practical purposes rather than logical ones are served by the arrangement adopted. The modern fanciful story is here placed next to the real folk story instead of after all the groups of folk products. The Hebrew stories at the beginning belong quite as well, perhaps even better, in Section V, while the stories at the end of Section VI shade off into the more modern types of short tales.</p>
             <p><span>The child's natural literature.</span> The world has lost certain secrets as the price of an advancing civilization.</p>
             <p>Without discussing the limits of the culture-epoch theory of human development as a complete guide in education, it is clear that the young child passes through a period when his mind looks out upon the world in a manner analogous to that of the folk as expressed in their literature.</p>
        </section>
    </body>
</html>
"""

private let sampleElements: [AnyEquatableContentElement] = [
    TextContentElement(
        locator: makeLocator(
            progression: 0.0,
            selector: "#pgepubid00498 > div.center",
            highlight: "171"
        ),
        role: .body,
        segments: [
            TextContentElement.Segment(
                locator: makeLocator(
                    progression: 0.0,
                    selector: "#pgepubid00498 > div.center",
                    highlight: "171"
                ),
                text: "171",
                attributes: [ContentAttribute(key: .language, value: Language("en"))]
            ),
        ]
    ).equatable(),
    TextContentElement(
        locator: makeLocator(
            progression: 0.2,
            selector: "#pgepubid00498 > h3",
            before: "171",
            highlight: "INTRODUCTORY"
        ),
        role: .body,
        segments: [
            TextContentElement.Segment(
                locator: makeLocator(
                    progression: 0.2,
                    selector: "#pgepubid00498 > h3",
                    before: "171",
                    highlight: "INTRODUCTORY"
                ),
                text: "INTRODUCTORY",
                attributes: [ContentAttribute(key: .language, value: Language("en"))]
            ),
        ]
    ).equatable(),
    TextContentElement(
        locator: makeLocator(
            progression: 0.4,
            selector: "#pgepubid00498 > p:nth-child(3)",
            before: "171INTRODUCTORY",
            highlight: "The difficulties of classification are very apparent here, and once more it must be noted that illustrative and practical purposes rather than logical ones are served by the arrangement adopted. The modern fanciful story is here placed next to the real folk story instead of after all the groups of folk products. The Hebrew stories at the beginning belong quite as well, perhaps even better, in Section V, while the stories at the end of Section VI shade off into the more modern types of short tales."
        ),
        role: .body,
        segments: [
            TextContentElement.Segment(
                locator: makeLocator(
                    progression: 0.4,
                    selector: "#pgepubid00498 > p:nth-child(3)",
                    before: "171INTRODUCTORY",
                    highlight: "The difficulties of classification are very apparent here, and once more it must be noted that illustrative and practical purposes rather than logical ones are served by the arrangement adopted. The modern fanciful story is here placed next to the real folk story instead of after all the groups of folk products. The Hebrew stories at the beginning belong quite as well, perhaps even better, in Section V, while the stories at the end of Section VI shade off into the more modern types of short tales."
                ),
                text: "The difficulties of classification are very apparent here, and once more it must be noted that illustrative and practical purposes rather than logical ones are served by the arrangement adopted. The modern fanciful story is here placed next to the real folk story instead of after all the groups of folk products. The Hebrew stories at the beginning belong quite as well, perhaps even better, in Section V, while the stories at the end of Section VI shade off into the more modern types of short tales.",
                attributes: [ContentAttribute(key: .language, value: Language("en"))]
            ),
        ]
    ).equatable(),
    TextContentElement(
        locator: makeLocator(
            progression: 0.6,
            selector: "#pgepubid00498 > p:nth-child(4)",
            before: "ade off into the more modern types of short tales.",
            highlight: "The child's natural literature. The world has lost certain secrets as the price of an advancing civilization."
        ),
        role: .body,
        segments: [
            TextContentElement.Segment(
                locator: makeLocator(
                    progression: 0.6,
                    selector: "#pgepubid00498 > p:nth-child(4)",
                    before: "ade off into the more modern types of short tales.",
                    highlight: "The child's natural literature. The world has lost certain secrets as the price of an advancing civilization."
                ),
                text: "The child's natural literature. The world has lost certain secrets as the price of an advancing civilization.",
                attributes: [ContentAttribute(key: .language, value: Language("en"))]
            ),
        ]
    ).equatable(),
    TextContentElement(
        locator: makeLocator(
            progression: 0.8,
            selector: "#pgepubid00498 > p:nth-child(5)",
            before: "secrets as the price of an advancing civilization.",
            highlight: "Without discussing the limits of the culture-epoch theory of human development as a complete guide in education, it is clear that the young child passes through a period when his mind looks out upon the world in a manner analogous to that of the folk as expressed in their literature."
        ),
        role: .body,
        segments: [
            TextContentElement.Segment(
                locator: makeLocator(
                    progression: 0.8,
                    selector: "#pgepubid00498 > p:nth-child(5)",
                    before: "secrets as the price of an advancing civilization.",
                    highlight: "Without discussing the limits of the culture-epoch theory of human development as a complete guide in education, it is clear that the young child passes through a period when his mind looks out upon the world in a manner analogous to that of the folk as expressed in their literature."
                ),
                text: "Without discussing the limits of the culture-epoch theory of human development as a complete guide in education, it is clear that the young child passes through a period when his mind looks out upon the world in a manner analogous to that of the folk as expressed in their literature.",
                attributes: [ContentAttribute(key: .language, value: Language("en"))]
            ),
        ]
    ).equatable(),
]

private func makeLocator(
    progression: Double? = nil,
    selector: String? = nil,
    before: String? = nil,
    highlight: String? = nil,
    after: String? = nil
) -> Locator {
    baseLocator.copy(
        locations: {
            $0.progression = progression
            if let selector = selector {
                $0.otherLocations = ["cssSelector": .string(selector)]
            }
        },
        text: {
            $0.after = after
            $0.before = before
            $0.highlight = highlight
        }
    )
}

private func makeIterator(
    _ html: String,
    start startLocator: Locator? = nil,
    totalProgressionRange: ClosedRange<Double>? = nil
) -> HTMLResourceContentIterator {
    HTMLResourceContentIterator(
        resource: DataResource(string: html),
        totalProgressionRange: { totalProgressionRange },
        locator: startLocator ?? makeLocator()
    )
}

/// Iterates all the elements of an HTML `body` fragment.
private func allElements(_ body: String) async throws -> [ContentElement] {
    let html = """
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml">
    <body>
    \(body)
    </body>
    </html>
    """

    let iter = makeIterator(html)
    var elements: [ContentElement] = []
    while let element = try await iter.next() {
        elements.append(element)
    }
    return elements
}
