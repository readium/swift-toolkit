//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@_spi(Experimental) @testable import ReadiumShared
import Testing
import UIKit

private let fixtures = Fixtures(path: "Publication/Services")
private let jpegData = fixtures.data(at: "cover.jpg")
private let cover = UIImage(data: jpegData)!
private let coverHREF = AnyURL(string: "~readium/cover")!

enum EmbeddedCoverServiceTests {
    struct Links {
        @Test func declaresTheMediaTypeOfTheCover() {
            let service = EmbeddedCoverService(data: jpegData, mediaType: .jpeg)
            #expect(service.links == [Link(href: "~readium/cover", mediaType: .jpeg, rels: [.cover])])
        }

        @Test func hasNoTypeWithoutADeclaredMediaType() {
            let service = EmbeddedCoverService(data: jpegData, mediaType: nil)
            #expect(service.links == [Link(href: "~readium/cover", rels: [.cover])])
        }
    }

    struct Get {
        @Test func servesTheOriginalBytes() async throws {
            let service = EmbeddedCoverService(data: jpegData, mediaType: .jpeg)
            let resource = try #require(service.get(coverHREF))
            #expect(try await resource.read().get() == jpegData)
        }

        /// The bytes are not converted to match the declared media type.
        @Test func servesTheOriginalBytesOfAMislabeledCover() async throws {
            let service = EmbeddedCoverService(data: jpegData, mediaType: .png)
            let resource = try #require(service.get(coverHREF))
            #expect(try await resource.read().get() == jpegData)
        }

        @Test func ignoresOtherHREFs() {
            let service = EmbeddedCoverService(data: jpegData, mediaType: .jpeg)
            #expect(service.get(AnyURL(string: "cover.jpg")!) == nil)
        }
    }

    struct Cover {
        @Test func decodesTheBitmap() async throws {
            let service = EmbeddedCoverService(data: jpegData, mediaType: .jpeg)
            let image = try await service.cover().get()
            #expect(image?.pngData() == cover.pngData())
        }

        @Test(arguments: [MediaType.png, nil])
        func doesNotDependOnTheDeclaredMediaType(mediaType: MediaType?) async throws {
            let service = EmbeddedCoverService(data: jpegData, mediaType: mediaType)
            let image = try await service.cover().get()
            #expect(image?.pngData() == cover.pngData())
        }

        @Test func returnsNilForUndecodableBytes() async throws {
            let service = EmbeddedCoverService(data: Data("not an image".utf8), mediaType: .jpeg)
            #expect(try await service.cover().get() == nil)
        }
    }

    struct CoverData {
        @Test func returnsTheOriginalBytesForAnAcceptedMediaType() async throws {
            let service = EmbeddedCoverService(data: jpegData, mediaType: .jpeg)
            let result = try await service.coverData(accepting: [.png, .jpeg])
            #expect(result?.mediaType == .jpeg)
            #expect(result?.data == jpegData)
        }

        @Test func returnsNilWhenTheDeclaredMediaTypeIsNotAccepted() async throws {
            let service = EmbeddedCoverService(data: jpegData, mediaType: .jpeg)
            #expect(try await service.coverData(accepting: [.png]) == nil)
        }

        @Test func returnsNilWithoutADeclaredMediaType() async throws {
            let service = EmbeddedCoverService(data: jpegData, mediaType: nil)
            #expect(try await service.coverData(accepting: [.jpeg, .png]) == nil)
        }
    }

    struct Factory {
        @Test func exposesTheCoverThroughThePublication() async throws {
            let publication = Publication(
                manifest: Manifest(metadata: Metadata(title: "title")),
                servicesBuilder: PublicationServicesBuilder(
                    cover: EmbeddedCoverService.makeFactory(data: jpegData, mediaType: .jpeg)
                )
            )

            let link = try #require(publication.linkWithRel(.cover))
            #expect(link.mediaType == .jpeg)
            #expect(try await publication.get(link)?.read().get() == jpegData)
            #expect(try await publication.cover().get()?.pngData() == cover.pngData())
        }
    }
}
