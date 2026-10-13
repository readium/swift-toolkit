//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A `Container` serving in-memory entries.
struct DataContainer: Container {
    let sourceURL: AbsoluteURL? = nil

    private let data: [AnyURL: Data]

    init(entries: [AnyURL: Data]) {
        data = entries
    }

    var entries: Set<AnyURL> {
        Set(data.keys)
    }

    subscript(url: any URLConvertible) -> Resource? {
        data[url.anyURL.normalized].map { DataResource(data: $0) }
    }
}
