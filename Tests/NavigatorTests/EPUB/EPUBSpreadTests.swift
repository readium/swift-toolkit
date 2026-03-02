//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

@Suite enum EPUBSpreadTests {
    @Suite("Single pages") struct SinglePages {
        @Test("with an empty reading order")
        func emptyReadingOrder() {
            let pub = fxlPublication(readingOrder: [])
            let spreads = makeSpreads(publication: pub, spread: false)
            #expect(spreads.isEmpty)
        }

        @Test("each link produces a single spread")
        func multipleLinks() {
            let pub = fxlPublication(readingOrder: [
                link("p1.html"),
                link("p2.html"),
                link("p3.html"),
            ])
            let spreads = makeSpreads(publication: pub, spread: false)

            #expect(spreads.count == 3)
            for (i, spread) in spreads.enumerated() {
                guard case let .single(s) = spread else {
                    Issue.record("Expected .single at index \(i)")
                    continue
                }
                #expect(s.resource.index == i)
            }
        }
    }

    @Suite("Dual pages") struct DualPages {
        @Test("never combines reflowable pages")
        func neverCombinesReflowable() {
            let pub = reflowablePublication(readingOrder: [
                link("c1.html"),
                link("c2.html"),
                link("c3.html"),
            ])
            let spreads = makeSpreads(publication: pub, spread: true)

            #expect(spreads.count == 3)
            for spread in spreads {
                guard case .single = spread else {
                    Issue.record("Expected all .single for reflowable")
                    return
                }
            }
        }

        @Suite("FXL") enum FXL {
            @Suite("First page position") struct FirstPagePosition {
                @Test("defaults to center when no page property")
                func firstPageDefaultsToCenter() {
                    let pub = fxlPublication(readingOrder: [
                        link("cover.html"),
                        link("p1.html", page: .left),
                        link("p2.html", page: .right),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true)

                    #expect(spreads.count == 2)
                    guard case let .single(cover) = spreads[0] else {
                        Issue.record("Expected cover to be .single")
                        return
                    }
                    #expect(cover.resource.link.href == "cover.html")
                    guard case .double = spreads[1] else {
                        Issue.record("Expected p1+p2 to be .double")
                        return
                    }
                }

                @Test("offsetFirstPage: true keeps first page single")
                func offsetFirstPageTrue() {
                    let pub = fxlPublication(readingOrder: [
                        link("cover.html"),
                        link("p1.html", page: .left),
                        link("p2.html", page: .right),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true, offsetFirstPage: true)

                    #expect(spreads.count == 2)
                    guard case .single = spreads[0] else {
                        Issue.record("Expected cover to be .single with offsetFirstPage=true")
                        return
                    }
                }

                @Test("offsetFirstPage: false allows first page to combine")
                func offsetFirstPageFalse() {
                    let pub = fxlPublication(readingOrder: [
                        link("p1.html"),
                        link("p2.html"),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true, offsetFirstPage: false)

                    #expect(spreads.count == 1)
                    guard case .double = spreads[0] else {
                        Issue.record("Expected .double when offsetFirstPage=false")
                        return
                    }
                }

                @Test("explicit .left on first page is preserved")
                func firstPageExplicitLeftKeepsIt() {
                    let pub = fxlPublication(readingOrder: [
                        link("p1.html", page: .left),
                        link("p2.html", page: .right),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true)

                    #expect(spreads.count == 1)
                    guard case .double = spreads[0] else {
                        Issue.record("Expected .double when first page has explicit .left")
                        return
                    }
                }
            }

            @Suite("Page pairing (LTR)") struct PairingLTR {
                @Test("left + right pages are combined")
                func leftRightCombined() {
                    let pub = fxlPublication(readingProgression: .ltr, readingOrder: [
                        link("cover.html", page: .center),
                        link("p1.html", page: .left),
                        link("p2.html", page: .right),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true)

                    #expect(spreads.count == 2)
                    guard case let .double(d) = spreads[1] else {
                        Issue.record("Expected left+right to combine in LTR")
                        return
                    }
                    #expect(d.first.link.href == "p1.html")
                    #expect(d.second.link.href == "p2.html")
                }

                @Test("right + left pages are not combined")
                func rightLeftNotCombined() {
                    let pub = fxlPublication(readingProgression: .ltr, readingOrder: [
                        link("cover.html", page: .center),
                        link("p1.html", page: .right),
                        link("p2.html", page: .left),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true)

                    #expect(spreads.count == 3)
                    for spread in spreads {
                        guard case .single = spread else {
                            Issue.record("Expected all .single for wrong-order LTR pages")
                            return
                        }
                    }
                }

                @Test("nil + nil defaults to left + right")
                func nilNilDefaultsToLeftRight() {
                    let pub = fxlPublication(readingProgression: .ltr, readingOrder: [
                        link("cover.html", page: .center),
                        link("p1.html"),
                        link("p2.html"),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true)

                    #expect(spreads.count == 2)
                    guard case .double = spreads[1] else {
                        Issue.record("Expected nil+nil to combine in LTR")
                        return
                    }
                }

                @Test("center + left pages are not combined")
                func centerLeftNotCombined() {
                    let pub = fxlPublication(readingProgression: .ltr, readingOrder: [
                        link("cover.html", page: .center),
                        link("p1.html", page: .center),
                        link("p2.html", page: .left),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true)

                    #expect(spreads.count == 3)
                }

                @Test("odd number of pages leaves last page single")
                func oddNumberLastPageSingle() {
                    let pub = fxlPublication(readingProgression: .ltr, readingOrder: [
                        link("cover.html", page: .center),
                        link("p1.html", page: .left),
                        link("p2.html", page: .right),
                        link("p3.html", page: .left),
                    ])
                    let spreads = makeSpreads(publication: pub, spread: true)

                    #expect(spreads.count == 3)
                    guard case .single = spreads[0] else {
                        Issue.record("Expected cover to be single")
                        return
                    }
                    guard case .double = spreads[1] else {
                        Issue.record("Expected p1+p2 to be double")
                        return
                    }
                    guard case let .single(last) = spreads[2] else {
                        Issue.record("Expected last page to be single")
                        return
                    }
                    #expect(last.resource.link.href == "p3.html")
                }
            }

            @Suite("Page pairing (RTL)") struct PairingRTL {
                @Test("right + left pages are combined")
                func rightLeftCombined() {
                    let pub = fxlPublication(readingProgression: .rtl, readingOrder: [
                        link("cover.html", page: .center),
                        link("p1.html", page: .right),
                        link("p2.html", page: .left),
                    ])
                    let spreads = makeSpreads(publication: pub, readingProgression: .rtl, spread: true)

                    #expect(spreads.count == 2)
                    guard case let .double(d) = spreads[1] else {
                        Issue.record("Expected right+left to combine in RTL")
                        return
                    }
                    #expect(d.first.link.href == "p1.html")
                    #expect(d.second.link.href == "p2.html")
                }

                @Test("left + right pages are not combined")
                func leftRightNotCombined() {
                    let pub = fxlPublication(readingProgression: .rtl, readingOrder: [
                        link("cover.html", page: .center),
                        link("p1.html", page: .left),
                        link("p2.html", page: .right),
                    ])
                    let spreads = makeSpreads(publication: pub, readingProgression: .rtl, spread: true)

                    #expect(spreads.count == 3)
                }

                @Test("nil + nil defaults to right + left")
                func nilNilDefaultsToRightLeft() {
                    let pub = fxlPublication(readingProgression: .rtl, readingOrder: [
                        link("cover.html", page: .center),
                        link("p1.html"),
                        link("p2.html"),
                    ])
                    let spreads = makeSpreads(publication: pub, readingProgression: .rtl, spread: true)

                    #expect(spreads.count == 2)
                    guard case .double = spreads[1] else {
                        Issue.record("Expected nil+nil to combine in RTL")
                        return
                    }
                }
            }
        }
    }

    @Suite enum Properties {
        @Suite struct SingleSpread {
            @Test func readingOrderIndices() {
                let spread = EPUBSpread.single(EPUBSingleSpread(
                    resource: EPUBSpreadResource(index: 3, link: link("p.html"))
                ))
                #expect(spread.readingOrderIndices == 3 ... 3)
            }

            @Test func first() {
                let resource = EPUBSpreadResource(index: 5, link: link("p.html"))
                let spread = EPUBSpread.single(EPUBSingleSpread(resource: resource))
                #expect(spread.first.index == 5)
                #expect(spread.first.link.href == "p.html")
            }

            @Test func containsIndex() {
                let single = EPUBSpread.single(EPUBSingleSpread(
                    resource: EPUBSpreadResource(index: 2, link: link("p.html"))
                ))
                #expect(single.contains(index: 2))
                #expect(!single.contains(index: 0))
                #expect(!single.contains(index: 3))
            }
        }

        @Suite struct DoubleSpread {
            @Test func readingOrderIndices() {
                let spread = EPUBSpread.double(EPUBDoubleSpread(
                    first: EPUBSpreadResource(index: 2, link: link("p1.html")),
                    second: EPUBSpreadResource(index: 3, link: link("p2.html"))
                ))
                #expect(spread.readingOrderIndices == 2 ... 3)
            }

            @Test func first() {
                let spread = EPUBSpread.double(EPUBDoubleSpread(
                    first: EPUBSpreadResource(index: 1, link: link("p1.html")),
                    second: EPUBSpreadResource(index: 2, link: link("p2.html"))
                ))
                #expect(spread.first.index == 1)
                #expect(spread.first.link.href == "p1.html")
            }

            @Test func containsIndex() {
                let double = EPUBSpread.double(EPUBDoubleSpread(
                    first: EPUBSpreadResource(index: 4, link: link("p1.html")),
                    second: EPUBSpreadResource(index: 5, link: link("p2.html"))
                ))
                #expect(double.contains(index: 4))
                #expect(double.contains(index: 5))
                #expect(!double.contains(index: 3))
                #expect(!double.contains(index: 6))
            }

            @Test("LTR: left is first, right is second")
            func ltrLeftIsFirstRightIsSecond() {
                let first = EPUBSpreadResource(index: 0, link: link("p1.html"))
                let second = EPUBSpreadResource(index: 1, link: link("p2.html"))
                let spread = EPUBDoubleSpread(first: first, second: second)

                #expect(spread.left(for: .ltr).link.href == "p1.html")
                #expect(spread.right(for: .ltr).link.href == "p2.html")
            }

            @Test("RTL: left is second, right is first")
            func rtlLeftIsSecondRightIsFirst() {
                let first = EPUBSpreadResource(index: 0, link: link("p1.html"))
                let second = EPUBSpreadResource(index: 1, link: link("p2.html"))
                let spread = EPUBDoubleSpread(first: first, second: second)

                #expect(spread.left(for: .rtl).link.href == "p2.html")
                #expect(spread.right(for: .rtl).link.href == "p1.html")
            }
        }
    }

    @Suite struct PositionCount {
        @Test("for a single spread")
        func single() {
            let readingOrder: ReadingOrder = [
                link("p0.html"),
                link("p1.html"),
                link("p2.html"),
            ]
            let positions: [[Locator]] = [
                [Locator(href: "p0.html", mediaType: .html)],
                [
                    Locator(href: "p1.html", mediaType: .html),
                    Locator(href: "p1.html", mediaType: .html),
                    Locator(href: "p1.html", mediaType: .html),
                ],
                [Locator(href: "p2.html", mediaType: .html)],
            ]

            let spread = EPUBSpread.single(EPUBSingleSpread(
                resource: EPUBSpreadResource(index: 1, link: link("p1.html"))
            ))
            #expect(spread.positionCount(in: readingOrder, positionsByReadingOrder: positions) == 3)
        }

        @Test("for a double spread sums both resources")
        func double() {
            let readingOrder: ReadingOrder = [
                link("p0.html"),
                link("p1.html"),
                link("p2.html"),
            ]
            let positions: [[Locator]] = [
                [Locator(href: "p0.html", mediaType: .html)],
                [
                    Locator(href: "p1.html", mediaType: .html),
                    Locator(href: "p1.html", mediaType: .html),
                ],
                [Locator(href: "p2.html", mediaType: .html)],
            ]

            let spread = EPUBSpread.double(EPUBDoubleSpread(
                first: EPUBSpreadResource(index: 1, link: link("p1.html")),
                second: EPUBSpreadResource(index: 2, link: link("p2.html"))
            ))
            #expect(spread.positionCount(in: readingOrder, positionsByReadingOrder: positions) == 3)
        }

        @Test("returns 0 for out-of-bounds index")
        func outOfBounds() {
            let readingOrder: ReadingOrder = [link("p0.html")]
            let positions: [[Locator]] = [[Locator(href: "p0.html", mediaType: .html)]]

            let spread = EPUBSpread.single(EPUBSingleSpread(
                resource: EPUBSpreadResource(index: 5, link: link("missing.html"))
            ))
            #expect(spread.positionCount(in: readingOrder, positionsByReadingOrder: positions) == 0)
        }
    }

    @Suite struct FirstIndexWithReadingOrderIndex {
        @Test("finds the spread index containing a reading order index")
        func findsSpreadIndex() {
            let spreads: [EPUBSpread] = [
                .single(EPUBSingleSpread(
                    resource: EPUBSpreadResource(index: 0, link: link("cover.html"))
                )),
                .double(EPUBDoubleSpread(
                    first: EPUBSpreadResource(index: 1, link: link("p1.html")),
                    second: EPUBSpreadResource(index: 2, link: link("p2.html"))
                )),
                .single(EPUBSingleSpread(
                    resource: EPUBSpreadResource(index: 3, link: link("p3.html"))
                )),
            ]

            #expect(spreads.firstIndexWithReadingOrderIndex(0) == 0)
            #expect(spreads.firstIndexWithReadingOrderIndex(1) == 1)
            #expect(spreads.firstIndexWithReadingOrderIndex(2) == 1)
            #expect(spreads.firstIndexWithReadingOrderIndex(3) == 2)
            #expect(spreads.firstIndexWithReadingOrderIndex(99) == nil)
        }
    }
}

// MARK: - Helpers

private func link(_ href: String, page: Properties.Page? = nil) -> Link {
    var properties = Properties()
    properties.page = page
    return Link(href: href, properties: properties)
}

private func fxlPublication(
    readingProgression: ReadiumShared.ReadingProgression = .auto,
    readingOrder: [Link]
) -> Publication {
    Publication(
        manifest: Manifest(
            metadata: Metadata(
                title: "FXL",
                layout: .fixed,
                readingProgression: readingProgression
            ),
            readingOrder: readingOrder
        )
    )
}

private func reflowablePublication(readingOrder: [Link]) -> Publication {
    Publication(
        manifest: Manifest(
            metadata: Metadata(title: "Reflowable"),
            readingOrder: readingOrder
        )
    )
}

private func makeSpreads(
    publication: Publication,
    readingProgression: ReadiumNavigator.ReadingProgression = .ltr,
    spread: Bool,
    offsetFirstPage: Bool? = nil
) -> [EPUBSpread] {
    EPUBSpread.makeSpreads(
        for: publication,
        readingOrder: publication.readingOrder,
        readingProgression: readingProgression,
        spread: spread,
        offsetFirstPage: offsetFirstPage
    )
}

private extension Locator {
    init(href: String, mediaType: MediaType) {
        self.init(href: AnyURL(string: href)!, mediaType: mediaType)
    }
}
