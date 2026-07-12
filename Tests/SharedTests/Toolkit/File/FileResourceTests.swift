//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import Testing
import TestPublications

struct FileResourceTests {
    private let file = FileURL(url: TestPublications.url(for: "childrens-literature.epub"))!

    @Test func streamFailsWhenTaskIsCancelled() async {
        let resource = FileResource(file: file)

        let task = Task { () -> ReadResult<Void> in
            // Waits until the cancellation below is requested, to make the
            // test deterministic.
            while !Task.isCancelled {
                await Task.yield()
            }
            return await resource.stream(range: nil) { _ in
                Issue.record("Received a chunk from a cancelled task")
            }
        }
        task.cancel()

        let result = await task.value
        guard case .failure(.cancelled) = result else {
            Issue.record("Expected .failure(.cancelled), got \(result)")
            return
        }
    }
}
