//
//  ContentProtectionServiceTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class ContentProtectionServiceTests: XCTestCase {

    func testLinks() {
        let service = TestContentProtectionService()
        
        XCTAssertEqual(
            service.links,
            [
                Link(
                    href: "/~readium/content-protection",
                    type: "application/vnd.readium.content-protection+json"
                ),
                Link(
                    href: "/~readium/rights/copy{?text,peek}",
                    type: "application/vnd.readium.rights.copy+json",
                    templated: true
                ),
                Link(
                    href: "/~readium/rights/print{?pageCount,peek}",
                    type: "application/vnd.readium.rights.print+json",
                    templated: true
                )
            ]
        )
    }
    
    func testGetContentProtection() throws {
        let service = TestContentProtectionService(
            isRestricted: true,
            error: Publication.OpeningError.notFound,
            credentials: "open sesame",
            rights: AllRestrictedUserRights(),
            name: .localized(["en": "DRM", "fr": "GDN"])
        )
        
        let resource = service.get(link: Link(href: "/~readium/content-protection"))

        XCTAssertEqual(
            try resource?.readAsString().get(),
            """
            {"error":"File not found","isRestricted":true,"name":{"en":"DRM","fr":"GDN"},"rights":{"canCopy":false,"canPrint":false}}
            """
        )
    }
    
    func testGetCopy() {
        let rights = TestUserRights(copyCount: 10)
        let service = TestContentProtectionService(rights: rights)

        XCTAssertEqual(try service.getCopy(text: "banana", peek: false).readAsString().get(), "{}")
        XCTAssertEqual(rights.copyCount, 4)
        XCTAssertThrowsError(try service.getCopy(text: "banana", peek: false).readAsString().get())
        XCTAssertEqual(rights.copyCount, 4)
    }
    
    func testGetPeekCopy() {
        let rights = TestUserRights(copyCount: 10)
        let service = TestContentProtectionService(rights: rights)

        XCTAssertEqual(try service.getCopy(text: "banana", peek: true).readAsString().get(), "{}")
        XCTAssertEqual(rights.copyCount, 10)
        XCTAssertEqual(try service.getCopy(text: "banana", peek: true).readAsString().get(), "{}")
        XCTAssertEqual(rights.copyCount, 10)
    }
    
    func testGetCopyBadRequest() {
        let rights = TestUserRights(copyCount: 10)
        let service = TestContentProtectionService(rights: rights)

        XCTAssertThrowsError(try service.get(link: Link(href: "/~readium/rights/copy?peek=query"))?.read().get())
    }
    
    func testGetPrint() {
        let rights = TestUserRights(printCount: 10)
        let service = TestContentProtectionService(rights: rights)
        
        XCTAssertEqual(try service.getPrint(pageCount: 6, peek: false).readAsString().get(), "{}")
        XCTAssertEqual(rights.printCount, 4)
        XCTAssertThrowsError(try service.getPrint(pageCount: 6, peek: false).readAsString().get())
        XCTAssertEqual(rights.printCount, 4)
    }
    
    func testGetPeekPrint() {
        let rights = TestUserRights(printCount: 10)
        let service = TestContentProtectionService(rights: rights)
        
        XCTAssertEqual(try service.getPrint(pageCount: 6, peek: true).readAsString().get(), "{}")
        XCTAssertEqual(rights.printCount, 10)
        XCTAssertEqual(try service.getPrint(pageCount: 6, peek: true).readAsString().get(), "{}")
        XCTAssertEqual(rights.printCount, 10)
    }
    
    func testGetPrintBadRequest() {
        let rights = TestUserRights(printCount: 10)
        let service = TestContentProtectionService(rights: rights)
        
        XCTAssertThrowsError(try service.get(link: Link(href: "/~readium/rights/print?peek=query"))?.read().get())
    }
    
    func testGetUnknown() {
        let service = TestContentProtectionService()
        
        let resource = service.get(link: Link(href: "/unknown"))
        
        XCTAssertNil(resource)
    }
    
    /// The Publication helpers will use the `ContentProtectionService` if there's one.
    func testPublicationHelpers() {
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
        XCTAssertFalse(publication.rights.canCopy)
        XCTAssertFalse(publication.rights.canCopy(text: String(repeating: "word", count: 99999)))
        XCTAssertFalse(publication.rights.copy(text: String(repeating: "word", count: 99999)))
        XCTAssertFalse(publication.rights.canPrint)
        XCTAssertFalse(publication.rights.canPrint(pageCount: 99999))
        XCTAssertFalse(publication.rights.print(pageCount: 99999))
        XCTAssertEqual(publication.protectionLocalizedName, .localized(["en": "DRM", "fr": "GDN"]))
        XCTAssertEqual(publication.protectionName, "DRM")
    }
    
    func testPublicationHelpersFallbacks() {
        let publication = makePublication(service: nil)
        
        XCTAssertFalse(publication.isProtected)
        XCTAssertFalse(publication.isRestricted)
        XCTAssertNil(publication.protectionError)
        XCTAssertNil(publication.credentials)
        XCTAssertTrue(publication.rights.canCopy)
        XCTAssertTrue(publication.rights.canCopy(text: String(repeating: "word", count: 99999)))
        XCTAssertTrue(publication.rights.copy(text: String(repeating: "word", count: 99999)))
        XCTAssertTrue(publication.rights.canPrint)
        XCTAssertTrue(publication.rights.canPrint(pageCount: 99999))
        XCTAssertTrue(publication.rights.print(pageCount: 99999))
        XCTAssertNil(publication.protectionLocalizedName)
        XCTAssertNil(publication.protectionName)
    }
    
    private func makePublication(service: ContentProtectionServiceFactory? = nil) -> Publication {
        return Publication(
            manifest: Manifest(
                metadata: Metadata(title: ""),
                readingOrder: [
                    Link(href: "chap1", type: "text/html")
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
        return try XCTUnwrap(get(link: Link(href: "/~readium/rights/copy?text=\(text)&peek=\(peek)")))
    }
    
    func getPrint(pageCount: Int, peek: Bool) throws -> Resource {
        return try XCTUnwrap(get(link: Link(href: "/~readium/rights/print?pageCount=\(pageCount)&peek=\(peek)")))
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
        return copyCount >= text.count
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
        return printCount >= pageCount
    }
    
    func print(pageCount: Int) -> Bool {
        guard canPrint(pageCount: pageCount) else {
            return false
        }
        printCount -= pageCount
        return true
    }
    
}
