//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class CoverServiceTests: XCTestCase {
    let fixtures = Fixtures(path: "Publication/Services")

    lazy var coverURL = fixtures.url(for: "cover.jpg")
    lazy var cover = UIImage(contentsOfFile: coverURL.path)!
    lazy var cover2 = UIImage(data: fixtures.data(at: "cover2.jpg"))!

    /// `Publication.cover` will use the `CoverService` if there's one.
    func testCoverHelperUsesCoverService() {
        let publication = makePublication { _ in TestCoverService(cover: self.cover2) }
        AssertImageEqual(publication.cover, cover2)
    }

    /// `Publication.cover` will try to fetch the cover from a manifest link with rel `cover`, if
    /// no `CoverService` is provided.
    func testCoverHelperFallsBackOnManifest() {
        let publication = makePublication()
        AssertImageEqual(publication.cover, cover)
    }

    /// `Publication.coverFitting` will use the `CoverService` if there's one.
    func testCoverFittingHelperUsesCoverService() {
        let size = CGSize(width: 100, height: 100)
        let publication = makePublication { _ in TestCoverService(cover: self.cover2) }
        AssertImageEqual(publication.coverFitting(maxSize: size), cover2.scaleToFit(maxSize: size))
    }

    /// `Publication.coverFitting` will try to fetch the cover from a manifest link with rel `cover`, if
    /// no `CoverService` is provided.
    func testCoverFittingHelperFallsBackOnManifest() {
        let size = CGSize(width: 100, height: 100)
        let publication = makePublication()
        AssertImageEqual(publication.coverFitting(maxSize: size), cover.scaleToFit(maxSize: size))
    }

    private func makePublication(cover: CoverServiceFactory? = nil) -> Publication {
        let coverPath = "/cover.jpg"
        return Publication(
            manifest: Manifest(
                metadata: Metadata(
                    title: "title"
                ),
                resources: [
                    Link(href: coverPath, rels: [.cover]),
                ]
            ),
            fetcher: FileFetcher(href: coverPath, path: coverURL),
            servicesBuilder: PublicationServicesBuilder(cover: cover)
        )
    }
}

private struct TestCoverService: CoverService {
    let cover: UIImage?
}
