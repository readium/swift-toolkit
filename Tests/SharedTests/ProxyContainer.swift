//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

final class ProxyContainer: Container {
    private let retrieve: (AnyURL) -> Resource?

    init(entries: Set<AnyURL> = [], _ retrieve: @escaping (AnyURL) -> Resource?) {
        self.entries = Set(entries.map(\.normalized))
        self.retrieve = retrieve
    }

    let sourceURL: AbsoluteURL? = nil
    let entries: Set<AnyURL>

    subscript(url: any URLConvertible) -> (any Resource)? {
        retrieve(url.anyURL.normalized)
    }
}
