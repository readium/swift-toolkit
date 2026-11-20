//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import Testing
import UIKit

@MainActor struct EPUBReflowableSpreadViewTests {
    struct ScrollModeContentOffsetCase: Sendable, CustomTestStringConvertible {
        let name: String
        let atStart: Bool
        let verticalText: Bool
        let contentSize: CGSize
        let expected: CGPoint

        var testDescription: String {
            name
        }
    }

    /// The offsets include the content inset, which holds the safe area,
    /// and keep the current offset on the other axis.
    @Test(arguments: [
        ScrollModeContentOffsetCase(
            name: "start with horizontal text",
            atStart: true,
            verticalText: false,
            contentSize: CGSize(width: 400, height: 5000),
            expected: CGPoint(x: 5, y: -62)
        ),
        ScrollModeContentOffsetCase(
            name: "end with horizontal text",
            atStart: false,
            verticalText: false,
            contentSize: CGSize(width: 400, height: 5000),
            expected: CGPoint(x: 5, y: 4234)
        ),
        ScrollModeContentOffsetCase(
            name: "start with vertical text",
            atStart: true,
            verticalText: true,
            contentSize: CGSize(width: 5000, height: 800),
            expected: CGPoint(x: 4625, y: 10)
        ),
        ScrollModeContentOffsetCase(
            name: "end with vertical text",
            atStart: false,
            verticalText: true,
            contentSize: CGSize(width: 5000, height: 800),
            expected: CGPoint(x: -20, y: 10)
        ),
    ])
    func scrollModeContentOffsetIncludesContentInset(_ test: ScrollModeContentOffsetCase) {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        scrollView.contentSize = test.contentSize
        scrollView.contentInset = UIEdgeInsets(top: 62, left: 20, bottom: 34, right: 25)
        scrollView.contentOffset = CGPoint(x: 5, y: 10)

        #expect(
            EPUBReflowableSpreadView.scrollModeContentOffset(
                of: scrollView,
                atStart: test.atStart,
                verticalText: test.verticalText
            ) == test.expected
        )
    }
}
