//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// The set of EPUB layouts used by the resources of a reading order.
///
/// A publication can mix reflowable and fixed-layout resources, so knowing
/// which layouts are actually rendered is what determines whether a setting
/// applies.
struct EPUBLayouts: Hashable, Sendable {
    /// Layouts of a reading order containing only reflowable resources.
    static let reflowable = EPUBLayouts(layouts: [.reflowable])

    private let layouts: Set<EPUBLayout>

    init(readingOrder: [Link], metadata: Metadata) {
        self.init(layouts: Set(readingOrder.map { metadata.epubLayout(of: $0) }))
    }

    private init(layouts: Set<EPUBLayout>) {
        self.layouts = layouts
    }

    /// Indicates whether the reading order contains at least one resource
    /// rendered with the given `layout`.
    func contains(_ layout: EPUBLayout) -> Bool {
        layouts.contains(layout)
    }
}
