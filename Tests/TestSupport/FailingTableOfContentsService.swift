//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Table of contents service failing to read the table of contents.
public struct FailingTableOfContentsService: TableOfContentsService {
    public init() {}

    public func tableOfContents() async -> ReadResult<[Link]> {
        .failure(.decoding("Broken"))
    }
}
