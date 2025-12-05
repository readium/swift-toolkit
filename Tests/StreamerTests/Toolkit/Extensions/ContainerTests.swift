//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class ContainerTests: XCTestCase {
    func testGuessTitleWithoutDirectories() {
        let container = TestContainer(hrefs: ["a.txt", "b.png"])
        XCTAssertNil(container.guessTitle())
    }

    func testGuessTitleWithOneRootDirectory() {
        let container = TestContainer(hrefs: ["Root%20Directory/b.png", "Root%20Directory/dir/c.png"])
        XCTAssertEqual(container.guessTitle(), "Root Directory")
    }

    func testGuessTitleWithOneRootDirectoryButRootFiles() {
        let container = TestContainer(hrefs: ["a.txt", "Root%20Directory/b.png", "Root%20Directory/dir/c.png"])
        XCTAssertNil(container.guessTitle())
    }

    func testGuessTitleWithOneRootDirectoryIgnoringRootFile() {
        let container = TestContainer(hrefs: [".hidden", "Root%20Directory/b.png", "Root%20Directory/dir/c.png"])
        XCTAssertEqual(container.guessTitle(ignoring: { url in url.lastPathSegment == ".hidden" }), "Root Directory")
    }

    func testGuessTitleWithSeveralDirectories() {
        let container = TestContainer(hrefs: ["a.txt", "dir1/b.png", "dir2/c.png"])
        XCTAssertNil(container.guessTitle())
    }

    func testGuessTitleIgnoresSingleFiles() {
        let container = TestContainer(hrefs: ["single"])
        XCTAssertNil(container.guessTitle())
    }
}

private struct TestContainer: Container {
    init(hrefs: [String]) {
        entries = Set(hrefs.map { AnyURL(string: $0)! })
    }

    let entries: Set<AnyURL>

    let sourceURL: (any AbsoluteURL)? = nil

    subscript(url: any URLConvertible) -> (any Resource)? { nil }
}
