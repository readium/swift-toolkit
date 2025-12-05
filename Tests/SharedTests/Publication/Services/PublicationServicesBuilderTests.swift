//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

protocol FooService: PublicationService {}
struct FooServiceA: FooService {}
class FooServiceB: FooService {}
struct FooServiceC: FooService { let wrapped: FooService? }

protocol BarService: PublicationService {}
struct BarServiceA: BarService {}

class PublicationServicesBuilderTests: XCTestCase {
    private let context = PublicationServiceContext(
        publication: Weak<Publication>(),
        manifest: Manifest(metadata: Metadata(title: "")),
        container: EmptyContainer()
    )

    func testInitWithCustomFactories() {
        let builder = PublicationServicesBuilder(
            cover: GeneratedCoverService.makeFactory(cover: UIImage()),
            positions: PerResourcePositionsService.makeFactory(fallbackMediaType: .text)
        )

        let services = builder.build(context: context)

        XCTAssert(services.count == 3)
        XCTAssert(services.contains { $0 is CoverService })
        XCTAssert(services.contains { $0 is PositionsService })
    }

    func testBuild() {
        var builder = PublicationServicesBuilder()
        builder.set(FooService.self) { _ in FooServiceA() }
        builder.set(BarService.self) { _ in BarServiceA() }

        let services = builder.build(context: context)

        XCTAssert(services.count == 3)
        XCTAssert(services.contains { $0 is FooServiceA })
        XCTAssert(services.contains { $0 is BarServiceA })
    }

    func testBuildDefault() {
        let builder = PublicationServicesBuilder()
        let services = builder.build(context: context)
        XCTAssertEqual(services.count, 1)
        XCTAssert(services.contains { $0 is DefaultLocatorService })
    }

    func testSetOverwrite() {
        var builder = PublicationServicesBuilder()
        builder.set(FooService.self) { _ in FooServiceA() }
        builder.set(FooService.self) { _ in FooServiceB() }

        let services = builder.build(context: context)

        XCTAssert(services.contains { $0 is FooServiceB })
    }

    func testRemoveExisting() {
        var builder = PublicationServicesBuilder()
        builder.set(FooService.self) { _ in FooServiceA() }
        builder.set(BarService.self) { _ in BarServiceA() }

        builder.remove(FooService.self)

        let services = builder.build(context: context)
        XCTAssert(services.contains { $0 is BarServiceA })
        XCTAssert(!services.contains { $0 is FooServiceA })
    }

    func testRemoveUnknown() {
        var builder = PublicationServicesBuilder()
        builder.set(FooService.self) { _ in FooServiceA() }

        builder.remove(BarService.self)

        let services = builder.build(context: context)
        XCTAssert(services.contains { $0 is FooServiceA })
    }

    func testWrap() {
        var builder = PublicationServicesBuilder()
        builder.set(FooService.self) { _ in FooServiceB() }
        builder.set(BarService.self) { _ in BarServiceA() }

        builder.decorate(FooService.self) { oldFactory in
            { context in FooServiceC(wrapped: oldFactory?(context) as? FooService) }
        }

        let services = builder.build(context: context)
        XCTAssert(services.contains { ($0 as? FooServiceC)?.wrapped is FooServiceB })
        XCTAssert(services.contains { $0 is BarServiceA })
    }
}
