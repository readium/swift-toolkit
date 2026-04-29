//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@_spi(Experimental) @testable import ReadiumShared
import Testing
import UIKit

private let fixtures = Fixtures(path: "Publication/Services")
private let coverURL = fixtures.url(for: "cover.jpg")
private let cover = UIImage(contentsOfFile: coverURL.path)!
private let cover2 = UIImage(data: fixtures.data(at: "cover2.jpg"))!

enum ResourceCoverServiceTests {
    @Suite("cover()") struct Cover {
        @Test func prioritizesExplicitCoverLinkOverReadingOrder() async throws {
            let pub = makePublication(
                readingOrder: [Link(href: "cover.jpg", mediaType: .jpeg)],
                resources: [Link(href: "cover2.jpg", mediaType: .jpeg, rel: .cover)]
            )
            let image = try await pub.cover().get()
            #expect(image?.pngData() == cover2.pngData())
        }

        @Test func fallsBackToNextCoverLinkOnMissingResource() async throws {
            let pub = makePublication(
                readingOrder: [],
                resources: [
                    Link(href: "missing.jpg", mediaType: .jpeg, rel: .cover),
                    Link(href: "cover2.jpg", mediaType: .jpeg, rel: .cover),
                ]
            )
            let image = try await pub.cover().get()
            #expect(image?.pngData() == cover2.pngData())
        }

        @Test func usesFirstBitmapReadingOrderItem() async throws {
            let pub = makePublication(
                readingOrder: [
                    Link(href: "cover.jpg", mediaType: .jpeg),
                    Link(href: "page2.jpg", mediaType: .jpeg),
                ],
                resources: []
            )
            let image = try await pub.cover().get()
            #expect(image?.pngData() == cover.pngData())
        }

        @Test func usesFirstReadingOrderBitmapAlternate() async throws {
            let pub = makePublication(
                readingOrder: [
                    Link(
                        href: "chapter1.xhtml",
                        mediaType: .xhtml,
                        alternates: [Link(href: "cover.jpg", mediaType: .jpeg)]
                    ),
                ],
                resources: []
            )
            let image = try await pub.cover().get()
            #expect(image?.pngData() == cover.pngData())
        }

        @Test func capsSVGCoverAtDefaultMaxSize() async throws {
            // SVG canvas is 1400×2100, which exceeds defaultCoverMaxSize.
            // cover() must cap it to the default maximum.
            let pub = makePublication(
                readingOrder: [],
                resources: [Link(href: "cover.svg", mediaType: .svg, rel: .cover)]
            )
            let image = try #require(try await pub.cover().get())
            #expect(image.size.width == 800)
            #expect(image.size.height == 1200)
        }

        @Test func returnsNilWhenNoCoverImageFound() async throws {
            let pub = makePublication(
                readingOrder: [Link(href: "chapter1.xhtml", mediaType: .xhtml)],
                resources: []
            )
            #expect(try await pub.cover().get() == nil)
        }
    }

    @Suite("coverFitting()") struct CoverFitting {
        @Test func doesNotUpscaleBitmap() async throws {
            // cover.jpg is 598×800; requesting a larger max size must not upscale it.
            let size = CGSize(width: 1000, height: 1200)
            let pub = makePublication(
                readingOrder: [],
                resources: [Link(href: "cover.jpg", mediaType: .jpeg, rel: .cover)]
            )
            let image = try await pub.coverFitting(maxSize: size).get()
            #expect(image?.pngData() == cover.pngData())
        }

        @Test func scalesDownBitmap() async throws {
            let size = CGSize(width: 100, height: 100)
            let pub = makePublication(
                readingOrder: [],
                resources: [Link(href: "cover.jpg", mediaType: .jpeg, rel: .cover)]
            )
            let image = try await pub.coverFitting(maxSize: size).get()
            #expect(image?.pngData() == cover.scaleToFit(maxSize: size).pngData())
        }

        @Test func scalesDownSVG() async throws {
            let size = CGSize(width: 75, height: 75)
            let pub = makePublication(
                readingOrder: [],
                resources: [Link(href: "cover.svg", mediaType: .svg, rel: .cover)]
            )
            let image = try #require(try await pub.coverFitting(maxSize: size).get())
            #expect(image.size.width == 50)
            #expect(image.size.height == 75)
        }

        @Test func doesNotUpscaleSVG() async throws {
            // SVG canvas is 1400×2100; requesting a larger max size must not upscale it.
            let pub = makePublication(
                readingOrder: [],
                resources: [Link(href: "cover.svg", mediaType: .svg, rel: .cover)]
            )
            let image = try #require(try await pub.coverFitting(maxSize: CGSize(width: 3000, height: 3000)).get())
            #expect(image.size.width == 1400)
            #expect(image.size.height == 2100)
        }
    }

    @Suite("coverData(accepting:)") struct CoverData {
        @Test func returnsDataForExplicitCoverLinkWithMatchingType() async throws {
            let pub = makePublication(
                readingOrder: [],
                resources: [Link(href: "cover.jpg", mediaType: .jpeg, rel: .cover)]
            )

            let result = try await pub.coverData(accepting: [.jpeg])
            #expect(result?.mediaType == .jpeg)
            #expect(result?.data == fixtures.data(at: "cover.jpg"))
        }

        @Test func returnsMatchingTypeEvenWhenListedLast() async throws {
            let pub = makePublication(
                readingOrder: [],
                resources: [
                    Link(href: "cover.jpg", mediaType: .jpeg, rel: .cover),
                    Link(href: "cover.png", mediaType: .png, rel: .cover),
                ]
            )

            let result = try await pub.coverData(accepting: [.png, .jpeg])
            #expect(result?.mediaType == .png)
            #expect(result?.data == fixtures.data(at: "cover.png"))
        }

        @Test func skipsExplicitCoverWhenTypeNotAccepted() async throws {
            let pub = makePublication(
                readingOrder: [],
                resources: [Link(href: "cover.jpg", mediaType: .jpeg, rel: .cover)]
            )
            // cover is JPEG but only PNG is accepted
            let result = try await pub.coverData(accepting: [.png])
            #expect(result == nil)
        }

        @Test func fallsBackToNextCoverLinkWhenFirstTypeNotAccepted() async throws {
            // First cover link is PNG, which is not in the accepted list
            let pub = makePublication(
                readingOrder: [],
                resources: [
                    Link(href: "cover.png", mediaType: .png, rel: .cover),
                    Link(href: "cover.jpg", mediaType: .jpeg, rel: .cover),
                ]
            )
            let result = try await pub.coverData(accepting: [.jpeg])
            #expect(result?.mediaType == .jpeg)
            #expect(result?.data == fixtures.data(at: "cover.jpg"))
        }

        @Test func fallsBackToNextCoverLinkWhenFirstResourceMissing() async throws {
            // First cover link type is accepted but the resource is absent from the container.
            let pub = makePublication(
                readingOrder: [],
                resources: [
                    Link(href: "missing.jpg", mediaType: .jpeg, rel: .cover),
                    Link(href: "cover.jpg", mediaType: .jpeg, rel: .cover),
                ]
            )
            let result = try await pub.coverData(accepting: [.jpeg])
            #expect(result?.mediaType == .jpeg)
            #expect(result?.data == fixtures.data(at: "cover.jpg"))
        }

        @Test func fallsBackToReadingOrderBitmapWhenNoCoverLink() async throws {
            let pub = makePublication(
                readingOrder: [Link(href: "cover.jpg", mediaType: .jpeg)],
                resources: []
            )
            let result = try await pub.coverData(accepting: [.jpeg])
            #expect(result?.mediaType == .jpeg)
            #expect(result?.data == fixtures.data(at: "cover.jpg"))
        }

        @Test func returnsSVGDataWhenAccepted() async throws {
            let pub = makePublication(
                readingOrder: [],
                resources: [Link(href: "cover.svg", mediaType: .svg, rel: .cover)]
            )
            let result = try await pub.coverData(accepting: [.svg])
            #expect(result?.mediaType == .svg)
            #expect(result?.data == fixtures.data(at: "cover.svg"))
        }

        @Test func fallsBackToAlternatesOfFirstReadingOrderItem() async throws {
            let pub = makePublication(
                readingOrder: [
                    Link(
                        href: "chapter1.xhtml",
                        mediaType: .xhtml,
                        alternates: [Link(href: "cover.jpg", mediaType: .jpeg)]
                    ),
                ],
                resources: []
            )
            let result = try await pub.coverData(accepting: [.jpeg])
            #expect(result?.mediaType == .jpeg)
            #expect(result?.data == fixtures.data(at: "cover.jpg"))
        }

        @Test func returnsNilWhenNoCoverFound() async throws {
            let pub = makePublication(
                readingOrder: [Link(href: "chapter1.xhtml", mediaType: .xhtml)],
                resources: []
            )
            let result = try await pub.coverData(accepting: [.jpeg, .png])
            #expect(result == nil)
        }
    }
}

private func makePublication(
    readingOrder: [Link],
    resources: [Link]
) -> Publication {
    var links = readingOrder + resources
    links.append(contentsOf: readingOrder.flatMap(\.alternates))
    links.append(contentsOf: resources.flatMap(\.alternates))

    return Publication(
        manifest: Manifest(
            metadata: Metadata(title: "title"),
            readingOrder: readingOrder,
            resources: resources
        ),
        container: CompositeContainer(
            links.map { link in
                SingleResourceContainer(
                    resource: FileResource(file: fixtures.url(for: link.href)),
                    at: link.url()
                )
            }
        )
    )
}
