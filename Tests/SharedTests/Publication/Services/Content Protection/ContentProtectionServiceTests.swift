//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class ContentProtectionServiceTests: XCTestCase {
    func testGetUnknown() {
        let service = TestContentProtectionService()

        let resource = service.get(link: Link(href: "/unknown"))

        XCTAssertNil(resource)
    }

    /// The Publication helpers will use the `ContentProtectionService` if there's one.
    func testPublicationHelpers() async {
        let publication = makePublication(service: { _ in
            TestContentProtectionService(
                isRestricted: true,
                error: Publication.OpeningError.notFound,
                credentials: "open sesame",
                rights: AllRestrictedUserRights(),
                name: .localized(["en": "DRM", "fr": "GDN"])
            )
        })

        XCTAssertTrue(publication.isProtected)
        XCTAssertTrue(publication.isRestricted)
        XCTAssertNotNil(publication.protectionError)
        XCTAssertEqual(publication.credentials, "open sesame")

        let r1 = await publication.rights.canCopy(text: String(repeating: "word", count: 99999))
        XCTAssertFalse(r1)

        let r2 = await publication.rights.copy(text: String(repeating: "word", count: 99999))
        XCTAssertFalse(r2)

        let r3 = await publication.rights.canPrint(pageCount: 99999)
        XCTAssertFalse(r3)

        let r4 = await publication.rights.print(pageCount: 99999)
        XCTAssertFalse(r4)

        XCTAssertEqual(publication.protectionLocalizedName, .localized(["en": "DRM", "fr": "GDN"]))
        XCTAssertEqual(publication.protectionName, "DRM")
    }

    func testPublicationHelpersFallbacks() async {
        let publication = makePublication(service: nil)

        XCTAssertFalse(publication.isProtected)
        XCTAssertFalse(publication.isRestricted)
        XCTAssertNil(publication.protectionError)
        XCTAssertNil(publication.credentials)

        let r1 = await publication.rights.canCopy(text: String(repeating: "word", count: 99999))
        XCTAssertTrue(r1)

        let r2 = await publication.rights.copy(text: String(repeating: "word", count: 99999))
        XCTAssertTrue(r2)

        let r3 = await publication.rights.canPrint(pageCount: 99999)
        XCTAssertTrue(r3)

        let r4 = await publication.rights.print(pageCount: 99999)
        XCTAssertTrue(r4)

        XCTAssertNil(publication.protectionLocalizedName)
        XCTAssertNil(publication.protectionName)
    }

    private func makePublication(service: ContentProtectionServiceFactory? = nil) -> Publication {
        Publication(
            manifest: Manifest(
                metadata: Metadata(title: ""),
                readingOrder: [
                    Link(href: "chap1", type: "text/html"),
                ]
            ),
            servicesBuilder: PublicationServicesBuilder(contentProtection: service)
        )
    }
}

struct TestContentProtectionService: ContentProtectionService {
    var isRestricted: Bool = false
    var error: Error? = nil
    var credentials: String? = nil
    var rights: UserRights = UnrestrictedUserRights()
    var name: LocalizedString? = nil

    func getCopy(text: String, peek: Bool) throws -> Resource {
        try XCTUnwrap(get(link: Link(href: "/~readium/rights/copy?text=\(text)&peek=\(peek)")))
    }

    func getPrint(pageCount: Int, peek: Bool) throws -> Resource {
        try XCTUnwrap(get(link: Link(href: "/~readium/rights/print?pageCount=\(pageCount)&peek=\(peek)")))
    }
}

final class TestUserRights: UserRights {
    var copyCount: Int
    var printCount: Int

    init(copyCount: Int = 10, printCount: Int = 10) {
        self.copyCount = copyCount
        self.printCount = printCount
    }

    var canCopy: Bool {
        copyCount > 0
    }

    func canCopy(text: String) -> Bool {
        copyCount >= text.count
    }

    func copy(text: String) -> Bool {
        guard canCopy(text: text) else {
            return false
        }
        copyCount -= text.count
        return true
    }

    var canPrint: Bool {
        printCount > 0
    }

    func canPrint(pageCount: Int) -> Bool {
        printCount >= pageCount
    }

    func print(pageCount: Int) -> Bool {
        guard canPrint(pageCount: pageCount) else {
            return false
        }
        printCount -= pageCount
        return true
    }
}
