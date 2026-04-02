//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing
import UIKit

private let fixtures = Fixtures(path: "Publication/Services")
private let coverURL = fixtures.url(for: "cover.jpg")
private let cover = UIImage(contentsOfFile: coverURL.path)!
private let cover2 = UIImage(data: fixtures.data(at: "cover2.jpg"))!

@Suite struct ResourceCoverServiceTests {
    @Suite("cover()") struct Cover {
        @Test func prioritizesExplicitCoverLinkOverReadingOrder() async throws {
            let pub = try Publication(
                manifest: Manifest(
                    metadata: Metadata(title: "title"),
                    readingOrder: [Link(href: "page1.jpg", mediaType: .jpeg)],
                    resources: [Link(href: "cover2.jpg", mediaType: .jpeg, rels: [.cover])]
                ),
                container: CompositeContainer(
                    SingleResourceContainer(
                        resource: FileResource(file: fixtures.url(for: "cover.jpg")),
                        at: #require(AnyURL(string: "page1.jpg"))
                    ),
                    SingleResourceContainer(
                        resource: FileResource(file: fixtures.url(for: "cover2.jpg")),
                        at: #require(AnyURL(string: "cover2.jpg"))
                    )
                )
            )
            let image = try await pub.cover().get()
            #expect(image?.pngData() == cover2.pngData())
        }

        @Test func fallsBackToNextCoverLinkOnMissingResource() async throws {
            let pub = try Publication(
                manifest: Manifest(
                    metadata: Metadata(title: "title"),
                    resources: [
                        Link(href: "missing.jpg", mediaType: .jpeg, rels: [.cover]),
                        Link(href: "cover2.jpg", mediaType: .jpeg, rels: [.cover]),
                    ]
                ),
                container: SingleResourceContainer(
                    resource: FileResource(file: fixtures.url(for: "cover2.jpg")),
                    at: #require(AnyURL(string: "cover2.jpg"))
                )
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

        @Test func usesSVGCoverLink() async throws {
            let pub = makePublication(
                resources: [Link(href: "cover-svg.svg", mediaType: .svg, rels: [.cover])],
                containerURL: fixtures.url(for: "cover-svg.svg"),
                containerHref: "cover-svg.svg"
            )
            #expect(try await pub.cover().get() != nil)
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
            let image = try await makePublication().coverFitting(maxSize: size).get()
            #expect(image?.pngData() == cover.pngData())
        }

        @Test func scalesDownBitmap() async throws {
            let size = CGSize(width: 100, height: 100)
            let pub = makePublication(
                readingOrder: [Link(href: "cover.jpg", mediaType: .jpeg)],
                resources: []
            )
            let image = try await pub.coverFitting(maxSize: size).get()
            #expect(image?.pngData() == cover.scaleToFit(maxSize: size).pngData())
        }

        @Test func scalesDownSVG() async throws {
            let size = CGSize(width: 75, height: 75)
            let pub = makePublication(
                resources: [Link(href: "cover-svg.svg", mediaType: .svg, rels: [.cover])],
                containerURL: fixtures.url(for: "cover-svg.svg"),
                containerHref: "cover-svg.svg"
            )
            let image = try #require(try await pub.coverFitting(maxSize: size).get())
            #expect(image.size.width == 50)
            #expect(image.size.height == 75)
        }

        @Test func doesNotUpscaleSVG() async throws {
            // SVG canvas is 100×150; requesting a larger max size must not upscale it.
            let pub = makePublication(
                resources: [Link(href: "cover-svg.svg", mediaType: .svg, rels: [.cover])],
                containerURL: fixtures.url(for: "cover-svg.svg"),
                containerHref: "cover-svg.svg"
            )
            let image = try #require(try await pub.coverFitting(maxSize: CGSize(width: 200, height: 300)).get())
            #expect(image.size.width == 100)
            #expect(image.size.height == 150)
        }
    }
}

private func makePublication(
    readingOrder: [Link] = [],
    resources: [Link] = [Link(href: "cover.jpg", mediaType: .jpeg, rels: [.cover])],
    cover: CoverServiceFactory? = nil,
    containerURL: FileURL? = nil,
    containerHref: String = "cover.jpg"
) -> Publication {
    var builder = PublicationServicesBuilder()
    if let cover { builder.setCoverServiceFactory(cover) }
    return Publication(
        manifest: Manifest(
            metadata: Metadata(title: "title"),
            readingOrder: readingOrder,
            resources: resources
        ),
        container: SingleResourceContainer(
            resource: FileResource(file: containerURL ?? coverURL),
            at: AnyURL(string: containerHref)!
        ),
        servicesBuilder: builder
    )
}
