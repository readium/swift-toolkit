//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import Testing

enum LinkTests {
    struct TableOfContentsFromTitles {
        @Test func holdsTheHREFTitleAndDurationOfTheTitledLinks() {
            let readingOrder = [
                Link(href: "1.mp3", mediaType: .mp3, title: "Part 1", bitrate: 64, duration: 10),
                Link(href: "2.mp3", mediaType: .mp3, duration: 15),
                Link(href: "3.mp3", mediaType: .mp3, title: " \n", duration: 20),
                Link(href: "4.mp3", mediaType: .mp3, title: "Part 4"),
            ]

            #expect(readingOrder.tableOfContentsFromTitles == [
                Link(href: "1.mp3", title: "Part 1", duration: 10),
                Link(href: "4.mp3", title: "Part 4"),
            ])
        }

        @Test(arguments: [
            ("no links", []),
            ("no titles", [nil, nil]),
            ("a single title", ["Part 1", nil]),
            ("a single non-blank title", ["Part 1", "", " \n"]),
        ] as [(String, [String?])])
        func isEmptyWithFewerThanTwoTitles(rule: String, titles: [String?]) {
            let readingOrder = titles.enumerated().map { index, title in
                Link(href: "\(index + 1).mp3", mediaType: .mp3, title: title)
            }

            #expect(readingOrder.tableOfContentsFromTitles.isEmpty)
        }
    }
}
