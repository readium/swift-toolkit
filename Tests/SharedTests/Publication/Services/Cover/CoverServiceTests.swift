//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class CoverServiceTests: XCTestCase {
    let fixtures = Fixtures(path: "Publication/Services")

    lazy var coverURL = fixtures.url(for: "cover.jpg")
    lazy var cover = UIImage(contentsOfFile: coverURL.path)!
    lazy var cover2 = UIImage(data: fixtures.data(at: "cover2.jpg"))!

    /// `Publication.cover` will use a custom `CoverService` if provided.
    func testCoverHelperUsesCustomCoverService() async {
        let cover2 = cover2
        let publication = makePublication { _ in TestCoverService(cover: cover2) }
        let result = await publication.cover()
        AssertImageEqual(result, .success(cover2))
    }

    /// `Publication.cover` uses `ResourceCoverService` by default.
    func testCoverHelperUsesResourceCoverServiceByDefault() async {
        let publication = makePublication()
        let result = await publication.cover()
        AssertImageEqual(result, .success(cover))
    }

    /// `Publication.coverFitting` will use a custom `CoverService` if provided.
    func testCoverFittingHelperUsesCustomCoverService() async {
        let size = CGSize(width: 100, height: 100)
        let cover2 = cover2
        let publication = makePublication { _ in TestCoverService(cover: cover2) }
        let result = await publication.coverFitting(maxSize: size)
        AssertImageEqual(result, .success(cover2.scaleToFit(maxSize: size)))
    }

    /// `Publication.coverFitting` uses `ResourceCoverService` by default.
    func testCoverFittingHelperUsesResourceCoverServiceByDefault() async {
        let size = CGSize(width: 100, height: 100)
        let publication = makePublication()
        let result = await publication.coverFitting(maxSize: size)
        AssertImageEqual(result, .success(cover.scaleToFit(maxSize: size)))
    }

    /// `ResourceCoverService` uses the first bitmap reading order item when no explicit `.cover`
    /// link is declared.
    func testResourceCoverServiceUsesFirstBitmapReadingOrderItem() async {
        let publication = makePublication(
            readingOrder: [
                Link(href: "cover.jpg", mediaType: .jpeg),
                Link(href: "page2.jpg", mediaType: .jpeg),
            ],
            resources: []
        )
        let result = await publication.cover()
        AssertImageEqual(result, .success(cover))
    }

    /// `ResourceCoverService` uses the first bitmap alternate of the first reading order item
    /// when that item is not a bitmap.
    func testResourceCoverServiceUsesFirstReadingOrderBitmapAlternate() async {
        let publication = makePublication(
            readingOrder: [
                Link(
                    href: "chapter1.xhtml",
                    mediaType: .xhtml,
                    alternates: [
                        Link(href: "cover.jpg", mediaType: .jpeg),
                    ]
                ),
            ],
            resources: []
        )
        let result = await publication.cover()
        AssertImageEqual(result, .success(cover))
    }

    /// `ResourceCoverService` returns nil when no explicit `.cover` link is declared and no bitmap
    /// is available.
    func testResourceCoverServiceReturnsNilWhenNoBitmapAvailable() async {
        let publication = makePublication(
            readingOrder: [Link(href: "chapter1.xhtml", mediaType: .xhtml)],
            resources: []
        )
        let result = await publication.cover()
        AssertImageEqual(result, .success(nil))
    }

    /// `ResourceCoverService` prioritizes explicit `.cover` links over first reading order item.
    func testResourceCoverServicePrioritizesExplicitCoverLink() async throws {
        let publication = try Publication(
            manifest: Manifest(
                metadata: Metadata(title: "title"),
                readingOrder: [
                    Link(href: "page1.jpg", mediaType: .jpeg),
                ],
                resources: [
                    Link(href: "cover2.jpg", rels: [.cover]),
                ]
            ),
            container: CompositeContainer(
                SingleResourceContainer(
                    resource: FileResource(file: fixtures.url(for: "cover.jpg")),
                    at: XCTUnwrap(AnyURL(string: "page1.jpg"))
                ),
                SingleResourceContainer(
                    resource: FileResource(file: fixtures.url(for: "cover2.jpg")),
                    at: XCTUnwrap(AnyURL(string: "cover2.jpg"))
                )
            )
        )
        let result = await publication.cover()
        AssertImageEqual(result, .success(cover2))
    }

    private func makePublication(
        readingOrder: [Link] = [],
        resources: [Link] = [Link(href: "cover.jpg", rels: [.cover])],
        cover: CoverServiceFactory? = nil
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
                resource: FileResource(file: coverURL),
                at: AnyURL(string: "cover.jpg")!
            ),
            servicesBuilder: builder
        )
    }
}

private struct TestCoverService: CoverService {
    let cover: UIImage?

    func cover() async -> ReadResult<UIImage?> {
        .success(cover)
    }
}
