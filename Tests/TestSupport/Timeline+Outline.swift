//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) import ReadiumShared

@_spi(ExperimentalTimeline)
public extension Timeline {
    /// One line per entry of the table of contents, with its index, title
    /// and HREF, indented by depth.
    var outline: [String] {
        func lines(_ entries: [TimelineTOCEntry], indent: String) -> [String] {
            entries.flatMap { entry -> [String] in
                ["\(indent)\(entry.id.index) \(entry.title) → \(entry.link.href)"]
                    + lines(entry.children, indent: indent + "  ")
            }
        }
        return lines(toc.entries, indent: "")
    }
}
