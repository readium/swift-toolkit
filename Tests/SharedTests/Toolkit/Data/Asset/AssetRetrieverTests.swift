//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class AssetRetrieverTests: XCTestCase {
    let fixtures = Fixtures(path: "Format")
    let sut = AssetRetriever(httpClient: DefaultHTTPClient())

    private func file(_ path: String) async -> Resource {
        FileResource(file: fixtures.url(for: path))
    }

    private func zip(_ path: String) async -> Container {
        try! await ZIPArchiveOpener().open(
            resource: file(path),
            format: .zip
        ).get().container
    }

    private func folder(_ path: String) async -> Container {
        try! await DirectoryContainer(directory: fixtures.url(for: path))
    }
}
