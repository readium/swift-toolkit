//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) import ReadiumShared

@_spi(ExperimentalTimeline)
public extension Timeline {
    /// One line per entry of the table of contents, with its id, title and
    /// HREF, indented by depth.
    ///
    /// An untitled entry shows its number, such as `#2`.
    var outline: [String] {
        func lines(_ entries: [TimelineTOCEntry], indent: String) -> [String] {
            entries.flatMap { entry -> [String] in
                let title = switch entry.title {
                case let .text(text): text
                case let .number(number): "#\(number)"
                }
                return ["\(indent)\(entry.id) \(title) → \(entry.link.href)"]
                    + lines(entry.children, indent: indent + "  ")
            }
        }
        return lines(toc.entries, indent: "")
    }
}
