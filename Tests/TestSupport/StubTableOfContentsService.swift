//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Table of contents service answering with a given result, and counting the
/// calls.
public final class StubTableOfContentsService: TableOfContentsService, @unchecked Sendable {
    private let toc: ReadResult<[Link]>
    private let lock = NSLock()
    private var calls = 0

    public init(_ toc: ReadResult<[Link]>) {
        self.toc = toc
    }

    /// Service failing to read the table of contents.
    public static func failing() -> StubTableOfContentsService {
        StubTableOfContentsService(.failure(.decoding("Broken")))
    }

    public var callCount: Int {
        lock.withLock { calls }
    }

    public func tableOfContents() async -> ReadResult<[Link]> {
        lock.withLock { calls += 1 }
        return toc
    }
}
