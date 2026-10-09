//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension [Link] {
    /// Returns a table of contents made of the titled links of this reading
    /// order, or an empty list when fewer than two links have a title.
    ///
    /// Used when an audiobook provides no table of contents.
    var tableOfContentsFromTitles: [Link] {
        let links = compactMap { link -> Link? in
            guard let title = link.title?.orNilIfBlank() else {
                return nil
            }
            return Link(href: link.href, title: title, duration: link.duration)
        }

        return links.count >= 2 ? links : []
    }
}
