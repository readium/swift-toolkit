//
//  Copyright 2025 Readium Foundation. All rights reserved.
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

    /// `Publication.cover` will use the `CoverService` if there's one.
    func testCoverHelperUsesCoverService() async {
        let publication = makePublication { _ in TestCoverService(cover: self.cover2) }
        let result = await publication.cover()
        AssertImageEqual(result, .success(cover2))
    }

    /// `Publication.cover` will try to fetch the cover from a manifest link with rel `cover`, if
    /// no `CoverService` is provided.
    func testCoverHelperFallsBackOnManifest() async {
        let publication = makePublication()
        let result = await publication.cover()
        AssertImageEqual(result, .success(cover))
    }

    /// `Publication.coverFitting` will use the `CoverService` if there's one.
    func testCoverFittingHelperUsesCoverService() async {
        let size = CGSize(width: 100, height: 100)
        let publication = makePublication { _ in TestCoverService(cover: self.cover2) }
        let result = await publication.coverFitting(maxSize: size)
        AssertImageEqual(result, .success(cover2.scaleToFit(maxSize: size)))
    }

    /// `Publication.coverFitting` will try to fetch the cover from a manifest link with rel `cover`, if
    /// no `CoverService` is provided.
    func testCoverFittingHelperFallsBackOnManifest() async {
        let size = CGSize(width: 100, height: 100)
        let publication = makePublication()
        let result = await publication.coverFitting(maxSize: size)
        AssertImageEqual(result, .success(cover.scaleToFit(maxSize: size)))
    }

    private func makePublication(cover: CoverServiceFactory? = nil) -> Publication {
        let coverPath = "cover.jpg"
        return Publication(
            manifest: Manifest(
                metadata: Metadata(
                    title: "title"
                ),
                readingOrder: [
                    Link(href: "titlepage.xhtml", rels: [.cover]),
                ],
                resources: [
                    Link(href: coverPath, rels: [.cover]),
                ]
            ),
            container: FileContainer(href: RelativeURL(path: coverPath)!, file: coverURL),
            servicesBuilder: PublicationServicesBuilder(cover: cover)
        )
    }
}

private struct TestCoverService: CoverService {
    let cover: UIImage?

    func cover() async -> ReadResult<UIImage?> {
        .success(cover)
    }
}
