//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class HTMLResourceContentIteratorTest: XCTestCase {
    private let link = Link(href: "/dir/res.xhtml", type: "application/xhtml+xml")
    private let locator = Locator(href: "/dir/res.xhtml", type: "application/xhtml+xml")

    private let html = """
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

    private lazy var elements: [AnyEquatableContentElement] = [
        TextContentElement(
            locator: locator(
                progression: 0.0,
                selector: "#pgepubid00498 > div.center",
                before: nil,
                highlight: "171"
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: locator(
                        progression: 0.0,
                        selector: "#pgepubid00498 > div.center",
                        before: nil,
                        highlight: "171"
                    ),
                    text: "171",
                    attributes: [ContentAttribute(key: .language, value: Language("en"))]
                ),
            ]
        ).equatable(),
        TextContentElement(
            locator: locator(
                progression: 0.2,
                selector: "#pgepubid00498 > h3",
                before: "171",
                highlight: "INTRODUCTORY"
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: locator(
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
            locator: locator(
                progression: 0.4,
                selector: "#pgepubid00498 > p:nth-child(3)",
                before: "171INTRODUCTORY",
                highlight: "The difficulties of classification are very apparent here, and once more it must be noted that illustrative and practical purposes rather than logical ones are served by the arrangement adopted. The modern fanciful story is here placed next to the real folk story instead of after all the groups of folk products. The Hebrew stories at the beginning belong quite as well, perhaps even better, in Section V, while the stories at the end of Section VI shade off into the more modern types of short tales."
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: locator(
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
            locator: locator(
                progression: 0.6,
                selector: "#pgepubid00498 > p:nth-child(4)",
                before: "ade off into the more modern types of short tales.",
                highlight: "The child's natural literature. The world has lost certain secrets as the price of an advancing civilization."
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: locator(
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
            locator: locator(
                progression: 0.8,
                selector: "#pgepubid00498 > p:nth-child(5)",
                before: "secrets as the price of an advancing civilization.",
                highlight: "Without discussing the limits of the culture-epoch theory of human development as a complete guide in education, it is clear that the young child passes through a period when his mind looks out upon the world in a manner analogous to that of the folk as expressed in their literature."
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: locator(
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

    private func locator(
        progression: Double? = nil,
        selector: String? = nil,
        before: String? = nil,
        highlight: String? = nil,
        after: String? = nil
    ) -> Locator {
        locator.copy(
            locations: {
                $0.progression = progression
                if let selector = selector {
                    $0.otherLocations = ["cssSelector": selector]
                }
            },
            text: {
                $0.after = after
                $0.before = before
                $0.highlight = highlight
            }
        )
    }

    private func iterator(
        _ html: String,
        start startLocator: Locator? = nil,
        totalProgressionRange: ClosedRange<Double>? = nil
    ) -> HTMLResourceContentIterator {
        HTMLResourceContentIterator(
            resource: DataResource(link: link, string: html),
            totalProgressionRange: totalProgressionRange,
            locator: startLocator ?? locator()
        )
    }

    func testIterateFromStartToFinish() throws {
        let iter = iterator(html)
        XCTAssertEqual(elements[0], try iter.next()?.equatable())
        XCTAssertEqual(elements[1], try iter.next()?.equatable())
        XCTAssertEqual(elements[2], try iter.next()?.equatable())
        XCTAssertEqual(elements[3], try iter.next()?.equatable())
        XCTAssertEqual(elements[4], try iter.next()?.equatable())
        XCTAssertNil(try iter.next())
    }

    func testPreviousIsNullFromTheBeginning() {
        let iter = iterator(html)
        XCTAssertNil(try iter.previous())
    }

    func testNextReturnsTheFirstElementFromTheBeginning() {
        let iter = iterator(html)
        XCTAssertEqual(elements[0], try iter.next()?.equatable())
    }

    func testNextThenPreviousReturnsNull() {
        let iter = iterator(html)
        XCTAssertEqual(elements[0], try iter.next()?.equatable())
        XCTAssertNil(try iter.previous())
    }

    func testNextTwiceThenPreviousReturnsTheFirstElement() {
        let iter = iterator(html)
        XCTAssertEqual(elements[0], try iter.next()?.equatable())
        XCTAssertEqual(elements[1], try iter.next()?.equatable())
        XCTAssertEqual(elements[0], try iter.previous()?.equatable())
    }

    func testStartingFromCSSSelector() {
        let iter = iterator(html, start: locator(selector: "#pgepubid00498 > p:nth-child(3)"))
        XCTAssertEqual(elements[2], try iter.next()?.equatable())
        XCTAssertEqual(elements[3], try iter.next()?.equatable())
        XCTAssertEqual(elements[4], try iter.next()?.equatable())
        XCTAssertNil(try iter.next())
    }

    func testCallingPreviousWhenStartingFromCSSSelector() {
        let iter = iterator(html, start: locator(selector: "#pgepubid00498 > p:nth-child(3)"))
        XCTAssertEqual(elements[1], try iter.previous()?.equatable())
    }

    func testStartingFromCSSSelectorToBlockElementContainingInlineElement() {
        let nbspHtml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr">
        <body>
            <p>Tout au loin sur la chaussée, aussi loin qu’on pouvait voir</p>
            <p>Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient <span>[...]</span> On buvait de la bière sucrée.</p>
        </body>
        </html>
        """

        let iter = iterator(nbspHtml, start: locator(selector: ":root > :nth-child(2) > :nth-child(2)"))

        let expectedElement = TextContentElement(
            locator: locator(
                progression: 0.5,
                selector: "html > body > p:nth-child(2)",
                before: "oin sur la chaussée, aussi loin qu’on pouvait voir",
                highlight: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée."
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: locator(
                        progression: 0.5,
                        selector: "html > body > p:nth-child(2)",
                        before: "oin sur la chaussée, aussi loin qu’on pouvait voir",
                        highlight: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée."
                    ),
                    text: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée.",
                    attributes: [ContentAttribute(key: .language, value: Language("fr"))]
                ),
            ]
        )

        XCTAssertEqual(expectedElement.equatable(), try iter.next()?.equatable())
    }

    func testStartingFromCSSSelectorUsingRootSelector() {
        let nbspHtml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr">
        <head></head>
        <body>
            <p>Tout au loin sur la chaussée, aussi loin qu’on pouvait voir</p>
            <p>Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient <span>[...]</span> On buvait de la bière sucrée.</p>
        </body>
        </html>
        """

        let iter = iterator(nbspHtml, start: locator(selector: ":root > :nth-child(2) > :nth-child(2)"))

        let expectedElement = TextContentElement(
            locator: locator(
                progression: 0.5,
                selector: "html > body > p:nth-child(2)",
                before: "oin sur la chaussée, aussi loin qu’on pouvait voir",
                highlight: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée."
            ),
            role: .body,
            segments: [
                TextContentElement.Segment(
                    locator: locator(
                        progression: 0.5,
                        selector: "html > body > p:nth-child(2)",
                        before: "oin sur la chaussée, aussi loin qu’on pouvait voir",
                        highlight: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée."
                    ),
                    text: "Lui, notre colonel, savait peut-être pourquoi ces deux gens-là tiraient [...] On buvait de la bière sucrée.",
                    attributes: [ContentAttribute(key: .language, value: Language("fr"))]
                ),
            ]
        )

        XCTAssertEqual(expectedElement.equatable(), try iter.next()?.equatable())
    }

    func testIteratingOverImageElements() {
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
                locator: locator(progression: 0.0, selector: "html > body > img:nth-child(1)"),
                embeddedLink: Link(href: "/dir/image.png"),
                caption: nil,
                attributes: []
            ).equatable(),
            ImageContentElement(
                locator: locator(progression: 0.5, selector: "html > body > img:nth-child(2)"),
                embeddedLink: Link(href: "/cover.jpg"),
                caption: nil,
                attributes: [ContentAttribute(key: .accessibilityLabel, value: "Accessibility description")]
            ).equatable(),
        ]

        let iter = iterator(html)
        XCTAssertEqual(expectedElements[0], try iter.next()?.equatable())
        XCTAssertEqual(expectedElements[1], try iter.next()?.equatable())
        XCTAssertNil(try iter.next())
    }

    func testIteratingOverAudioElements() {
        let html = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
            <audio src="audio.mp3" />
            <audio>
                <source src="audio.mp3" type="audio/mp3" />
                <source src="audio.ogg" type="audio/ogg" />
            </audio>
        </body>
        </html>
        """

        let expectedElements: [AnyEquatableContentElement] = [
            AudioContentElement(
                locator: locator(progression: 0.0, selector: "html > body > audio:nth-child(1)"),
                embeddedLink: Link(href: "/dir/audio.mp3"),
                attributes: []
            ).equatable(),
            AudioContentElement(
                locator: locator(progression: 0.5, selector: "html > body > audio:nth-child(2)"),
                embeddedLink: Link(
                    href: "/dir/audio.mp3",
                    type: "audio/mp3",
                    alternates: [Link(href: "/dir/audio.ogg", type: "audio/ogg")]
                ),
                attributes: []
            ).equatable(),
        ]

        let iter = iterator(html)
        XCTAssertEqual(expectedElements[0], try iter.next()?.equatable())
        XCTAssertEqual(expectedElements[1], try iter.next()?.equatable())
        XCTAssertNil(try iter.next())
    }

    func testIteratingOverVideoElements() {
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
                locator: locator(progression: 0.0, selector: "html > body > video:nth-child(1)"),
                embeddedLink: Link(href: "/dir/video.mp4"),
                attributes: []
            ).equatable(),
            VideoContentElement(
                locator: locator(progression: 0.5, selector: "html > body > video:nth-child(2)"),
                embeddedLink: Link(
                    href: "/dir/video.mp4",
                    type: "video/mp4",
                    alternates: [Link(href: "/dir/video.m4v", type: "video/x-m4v")]
                ),
                attributes: []
            ).equatable(),
        ]

        let iter = iterator(html)
        XCTAssertEqual(expectedElements[0], try iter.next()?.equatable())
        XCTAssertEqual(expectedElements[1], try iter.next()?.equatable())
        XCTAssertNil(try iter.next())
    }

    func testIteratingOverElementContainingTextAndChildElements() {
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
                locator: locator(
                    progression: 0.0,
                    selector: "#c06-li-0001",
                    highlight: "Let's start at the top—the source of ideas.",
                    after: "\n            "
                ),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: locator(
                            progression: 0.0,
                            selector: "#c06-li-0001",
                            highlight: "Let's start at the top—the source of ideas.",
                            after: "\n            "
                        ),
                        text: "Let's start at the top—the source of ideas.",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
            TextContentElement(
                locator: locator(
                    progression: 1 / 3.0,
                    selector: "#c06-para-0019",
                    before: "start at the top—the source of ideas.\n            ",
                    highlight: "While almost everyone today claims to be Agile, what I've just described is very much a waterfall process."
                ),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: locator(
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
                locator: locator(
                    progression: 2 / 3.0,
                    selector: "#c06-para-0019",
                    before: "e just described is very much a waterfall process.\n            \n            ",
                    highlight: "Trailing text",
                    after: "\n        "
                ),
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: locator(
                            progression: 2 / 3.0,
                            selector: "#c06-para-0019",
                            before: "e just described is very much a waterfall process.\n            ",
                            highlight: "Trailing text",
                            after: "\n        "
                        ),
                        text: "Trailing text",
                        attributes: []
                    ),
                ],
                attributes: []
            ).equatable(),
        ]

        let iter = iterator(html)
        XCTAssertEqual(expectedElements[0], try iter.next()?.equatable())
        XCTAssertEqual(expectedElements[1], try iter.next()?.equatable())
        XCTAssertEqual(expectedElements[2], try iter.next()?.equatable())
        XCTAssertNil(try iter.next())
    }
}

private extension ContentElement {
    func equatable() -> AnyEquatableContentElement {
        AnyEquatableContentElement(self)
    }
}
