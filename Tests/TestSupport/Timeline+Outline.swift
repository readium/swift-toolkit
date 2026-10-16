//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) import ReadiumShared

@_spi(ExperimentalTimeline)
public extension Timeline {
    /// One line per item, with its id, title and HREF, indented by depth.
    ///
    /// An untitled item shows its number, such as `#2`.
    var outline: [String] {
        func lines(_ items: [TimelineItem], indent: String) -> [String] {
            items.flatMap { item -> [String] in
                let title = switch item.title {
                case let .text(text): text
                case let .number(number): "#\(number)"
                }
                return ["\(indent)\(item.id) \(title) → \(item.link.href)"]
                    + lines(item.children, indent: indent + "  ")
            }
        }
        return lines(items, indent: "")
    }
}
