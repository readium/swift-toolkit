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

@Suite struct CoverServiceTests {
    @Suite struct PublicationHelpers {
        @Test func coverDelegatesToCustomService() async throws {
            let pub = makePublication { _ in TestCoverService(cover: cover2) }
            let image = try await pub.cover().get()
            #expect(image?.pngData() == cover2.pngData())
        }

        @Test func coverUsesResourceCoverServiceByDefault() async throws {
            let image = try await makePublication().cover().get()
            #expect(image?.pngData() == cover.pngData())
        }

        @Test func coverReturnsNilWithoutService() async throws {
            let image = try await makePublicationWithoutCoverService().cover().get()
            #expect(image == nil)
        }

        @Test func coverFittingDelegatesToCustomService() async throws {
            let size = CGSize(width: 100, height: 100)
            let pub = makePublication { _ in TestCoverService(cover: cover2) }
            let image = try await pub.coverFitting(maxSize: size).get()
            #expect(image?.pngData() == cover2.scaleToFit(maxSize: size).pngData())
        }

        @Test func coverFittingUsesResourceCoverServiceByDefault() async throws {
            let size = CGSize(width: 100, height: 100)
            let image = try await makePublication().coverFitting(maxSize: size).get()
            #expect(image?.pngData() == cover.scaleToFit(maxSize: size).pngData())
        }

        @Test func coverFittingReturnsNilWithoutService() async throws {
            let image = try await makePublicationWithoutCoverService()
                .coverFitting(maxSize: CGSize(width: 100, height: 100)).get()
            #expect(image == nil)
        }
    }
}

private func makePublication(
    cover: CoverServiceFactory? = nil
) -> Publication {
    var builder = PublicationServicesBuilder()
    if let cover { builder.setCoverServiceFactory(cover) }
    return Publication(
        manifest: Manifest(
            metadata: Metadata(title: "title"),
            resources: [Link(href: "cover.jpg", mediaType: .jpeg, rels: [.cover])]
        ),
        container: SingleResourceContainer(
            resource: FileResource(file: coverURL),
            at: AnyURL(string: "cover.jpg")!
        ),
        servicesBuilder: builder
    )
}

private func makePublicationWithoutCoverService() -> Publication {
    Publication(
        manifest: Manifest(metadata: Metadata(title: "title")),
        container: SingleResourceContainer(
            resource: FileResource(file: coverURL),
            at: AnyURL(string: "cover.jpg")!
        ),
        servicesBuilder: PublicationServicesBuilder(cover: nil)
    )
}

private struct TestCoverService: CoverService {
    let cover: UIImage?

    func cover() async -> ReadResult<UIImage?> {
        .success(cover)
    }
}
