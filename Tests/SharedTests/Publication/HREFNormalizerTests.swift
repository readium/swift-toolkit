//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class HREFNormalizerTests: XCTestCase {
    let manifest = Manifest(
        links: [
            Link(
                href: "https://domain/manifest.json",
                rel: .self
            ),
            Link(
                href: "file1",
                children: [
                    Link(href: "child1"),
                ]
            ),
            Link(href: "http://host/file1"),
        ],
        readingOrder: [
            Link(
                href: "file2",
                children: [
                    Link(href: "child2"),
                ]
            ),
            Link(href: "http://host/file2"),
        ],
        resources: [
            Link(
                href: "file3",
                children: [
                    Link(href: "child3"),
                ]
            ),
            Link(href: "http://host/file3"),
        ]
    )

    func testNormalizeManifestHREFsToSelf() throws {
        var sut = manifest
        try sut.normalizeHREFsToSelf()
        XCTAssertEqual(
            sut,
            Manifest(
                links: [
                    Link(
                        href: "https://domain/manifest.json",
                        rel: .self
                    ),
                    Link(
                        href: "https://domain/file1",
                        children: [
                            Link(href: "https://domain/child1"),
                        ]
                    ),
                    Link(href: "http://host/file1"),
                ],
                readingOrder: [
                    Link(
                        href: "https://domain/file2",
                        children: [
                            Link(href: "https://domain/child2"),
                        ]
                    ),
                    Link(href: "http://host/file2"),
                ],
                resources: [
                    Link(
                        href: "https://domain/file3",
                        children: [
                            Link(href: "https://domain/child3"),
                        ]
                    ),
                    Link(href: "http://host/file3"),
                ]
            )
        )
    }

    func testNormalizeManifestHREFsToBaseURL() throws {
        var sut = manifest
        try sut.normalizeHREFs(to: AnyURL(string: "https://other/dir/")!)

        XCTAssertEqual(
            sut,
            Manifest(
                links: [
                    Link(
                        href: "https://domain/manifest.json",
                        rel: .self
                    ),
                    Link(
                        href: "https://other/dir/file1",
                        children: [
                            Link(href: "https://other/dir/child1"),
                        ]
                    ),
                    Link(href: "http://host/file1"),
                ],
                readingOrder: [
                    Link(
                        href: "https://other/dir/file2",
                        children: [
                            Link(href: "https://other/dir/child2"),
                        ]
                    ),
                    Link(href: "http://host/file2"),
                ],
                resources: [
                    Link(
                        href: "https://other/dir/file3",
                        children: [
                            Link(href: "https://other/dir/child3"),
                        ]
                    ),
                    Link(href: "http://host/file3"),
                ]
            )
        )
    }

    func testNormalizeLinkHREFsToBaseURL() throws {
        var sut = Link(
            href: "href1",
            alternates: [
                Link(href: "dir/alternate2"),
                Link(href: "https://absolute"),
                Link(
                    href: "../alternate3",
                    children: [
                        Link(href: "child3"),
                    ]
                ),
            ],
            children: [
                Link(href: "dir/child1"),
                Link(href: "https://absolute"),
                Link(
                    href: "../child2",
                    alternates: [
                        Link(href: "alternate1"),
                    ]
                ),
            ]
        )
        try sut.normalizeHREFs(to: AnyURL(string: "https://other/dir/")!)

        XCTAssertEqual(
            sut,
            Link(
                href: "https://other/dir/href1",
                alternates: [
                    Link(href: "https://other/dir/dir/alternate2"),
                    Link(href: "https://absolute"),
                    Link(
                        href: "https://other/alternate3",
                        children: [
                            Link(href: "https://other/dir/child3"),
                        ]
                    ),
                ],
                children: [
                    Link(href: "https://other/dir/dir/child1"),
                    Link(href: "https://absolute"),
                    Link(
                        href: "https://other/child2",
                        alternates: [
                            Link(href: "https://other/dir/alternate1"),
                        ]
                    ),
                ]
            )
        )
    }
}
