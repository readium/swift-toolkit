//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class EPUBPositionsServiceTests: XCTestCase {
    func testFromEmptyReadingOrder() async {
        let service = makeService(readingOrder: [])
        let result = await service.positionsByReadingOrder()
        XCTAssertEqual(result, .success([]))
    }

    func testFromReadingOrderWithOneResource() async {
        let service = makeService(readingOrder: [(1, Link(href: "res", mediaType: .xml), nil)])

        let result = await service.positionsByReadingOrder()
        XCTAssertEqual(result, .success([[
            Locator(
                href: "res",
                mediaType: .xml,
                locations: Locator.Locations(
                    progression: 0,
                    totalProgression: 0,
                    position: 1
                )
            ),
        ]]))
    }

    func testFromReadingOrderWithFewResources() async {
        let service = makeService(readingOrder: [
            (1, Link(href: "res"), nil),
            (2, Link(href: "chap1", mediaType: .xml), nil),
            (2, Link(href: "chap2", mediaType: .html, title: "Chapter 2"), nil),
        ])

        let result = await service.positionsByReadingOrder()
        XCTAssertEqual(result, .success([
            [Locator(
                href: "res",
                mediaType: .html,
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.0,
                    position: 1
                )
            )],
            [Locator(
                href: "chap1",
                mediaType: .xml,
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 1.0 / 3.0,
                    position: 2
                )
            )],
            [Locator(
                href: "chap2",
                mediaType: .html,
                title: "Chapter 2",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 2.0 / 3.0,
                    position: 3
                )
            )],
        ]))
    }

    func testTypeFallsBackOnHTML() async {
        let service = makeService(readingOrder: [
            (1, Link(href: "chap1", properties: makeProperties(layout: .reflowable)), nil),
            (1, Link(href: "chap2", properties: makeProperties(layout: .fixed)), nil),
        ])

        let result = await service.positionsByReadingOrder()
        XCTAssertEqual(result, .success([
            [Locator(
                href: "chap1",
                mediaType: .html,
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.0,
                    position: 1
                )
            )],
            [Locator(
                href: "chap2",
                mediaType: .html,
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.5,
                    position: 2
                )
            )],
        ]))
    }

    func testOnePositionPerFixedLayoutResource() async {
        let service = makeService(
            layout: .fixed,
            readingOrder: [
                (10000, Link(href: "res"), nil),
                (20000, Link(href: "chap1", mediaType: .xml), nil),
                (40000, Link(href: "chap2", mediaType: .html, title: "Chapter 2"), nil),
            ]
        )

        let result = await service.positionsByReadingOrder()
        XCTAssertEqual(result, .success([
            [Locator(
                href: "res",
                mediaType: .html,
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.0,
                    position: 1
                )
            )],
            [Locator(
                href: "chap1",
                mediaType: .xml,
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 1.0 / 3.0,
                    position: 2
                )
            )],
            [Locator(
                href: "chap2",
                mediaType: .html,
                title: "Chapter 2",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 2.0 / 3.0,
                    position: 3
                )
            )],
        ]))
    }

    func testSplitReflowableResourcesByProvidedLength() async {
        let service = makeService(
            layout: .reflowable,
            readingOrder: [
                (0, Link(href: "chap1"), nil),
                (49, Link(href: "chap2", mediaType: .xml), nil),
                (50, Link(href: "chap3", mediaType: .html, title: "Chapter 3"), nil),
                (51, Link(href: "chap4"), nil),
                (120, Link(href: "chap5"), nil),
            ],
            reflowableStrategy: .archiveEntryLength(pageLength: 50)
        )

        let result = await service.positionsByReadingOrder()
        XCTAssertEqual(result, .success([
            [
                Locator(
                    href: "chap1",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 0.0,
                        position: 1
                    )
                ),
            ],
            [
                Locator(
                    href: "chap2",
                    mediaType: .xml,
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 1.0 / 8.0,
                        position: 2
                    )
                ),
            ],
            [
                Locator(
                    href: "chap3",
                    mediaType: .html,
                    title: "Chapter 3",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 2.0 / 8.0,
                        position: 3
                    )
                ),
            ],
            [
                Locator(
                    href: "chap4",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 3.0 / 8.0,
                        position: 4
                    )
                ),
                Locator(
                    href: "chap4",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 0.5,
                        totalProgression: 4.0 / 8.0,
                        position: 5
                    )
                ),
            ],
            [
                Locator(
                    href: "chap5",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 5.0 / 8.0,
                        position: 6
                    )
                ),
                Locator(
                    href: "chap5",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 1.0 / 3.0,
                        totalProgression: 6.0 / 8.0,
                        position: 7
                    )
                ),
                Locator(
                    href: "chap5",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 2.0 / 3.0,
                        totalProgression: 7.0 / 8.0,
                        position: 8
                    )
                ),
            ],
        ]))
    }

    func testLayoutFallsBackToReflowable() async {
        // We check this by verifying that the resource will be split every 50 bytes
        let service = makeService(
            layout: nil,
            readingOrder: [
                (60, Link(href: "chap1"), nil),
            ],
            reflowableStrategy: .archiveEntryLength(pageLength: 50)
        )

        let result = await service.positionsByReadingOrder()
        XCTAssertEqual(result, .success([[
            Locator(
                href: "chap1",
                mediaType: .html,
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.0,
                    position: 1
                )
            ),
            Locator(
                href: "chap1",
                mediaType: .html,
                locations: Locator.Locations(
                    progression: 0.5,
                    totalProgression: 0.5,
                    position: 2
                )
            ),
        ]]))
    }

    func testArchiveEntryLengthStrategy() async {
        let service = makeService(
            layout: .reflowable,
            readingOrder: [
                (60, Link(href: "chap1"), ArchiveProperties(entryLength: 20, isEntryCompressed: false)),
                (60, Link(href: "chap2"), nil),
            ],
            reflowableStrategy: .archiveEntryLength(pageLength: 50)
        )

        let result = await service.positionsByReadingOrder()
        XCTAssertEqual(result, .success([
            [
                Locator(
                    href: "chap1",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 0.0,
                        position: 1
                    )
                ),
            ],
            [
                Locator(
                    href: "chap2",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 1.0 / 3.0,
                        position: 2
                    )
                ),
                Locator(
                    href: "chap2",
                    mediaType: .html,
                    locations: Locator.Locations(
                        progression: 0.5,
                        totalProgression: 2.0 / 3.0,
                        position: 3
                    )
                ),
            ],
        ]))
    }
}

func makeService(layout: Layout? = nil, readingOrder: [(UInt64, Link, ArchiveProperties?)], reflowableStrategy: EPUBPositionsService.ReflowableStrategy = .archiveEntryLength(pageLength: 50)) -> EPUBPositionsService {
    EPUBPositionsService(
        readingOrder: readingOrder.map { _, l, _ in l },
        layout: layout,
        container: MockContainer(readingOrder: readingOrder),
        reflowableStrategy: reflowableStrategy
    )
}

private func makeProperties(layout: EPUBLayout? = nil, originalLength: Int? = nil) -> Properties {
    var props: [String: Any] = [:]
    if let layout = layout {
        props["layout"] = layout.rawValue
    }
    if let originalLength = originalLength {
        props["encrypted"] = [
            "algorithm": "algo",
            "originalLength": originalLength,
        ] as [String: Any]
    }
    return Properties(props)
}

private class MockContainer: Container {
    private let readingOrder: [(UInt64, Link, ArchiveProperties?)]

    init(readingOrder: [(UInt64, Link, ArchiveProperties?)]) {
        self.readingOrder = readingOrder
    }

    let sourceURL: AbsoluteURL? = nil

    var entries: Set<AnyURL> { Set(readingOrder.map { $0.1.url() }) }

    subscript(url: any URLConvertible) -> (any Resource)? {
        guard let (length, _, archiveProperties) = readingOrder.first(where: { _, link, _ in link.url().isEquivalentTo(url) }) else {
            return nil
        }
        return MockResource(length: length, archiveProperties: archiveProperties)
    }

    struct MockResource: Resource {
        private let _length: UInt64
        private let _properties: ResourceProperties

        init(length: UInt64, archiveProperties: ArchiveProperties?) {
            _length = length
            var props = ResourceProperties()
            props.archive = archiveProperties
            _properties = props
        }

        let sourceURL: (any AbsoluteURL)? = nil

        func estimatedLength() async -> ReadResult<UInt64?> {
            .success(_length)
        }

        func properties() async -> ReadResult<ResourceProperties> {
            .success(_properties)
        }

        func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
            consume(Data())
            return .success(())
        }
    }
}
