//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Set where Element == AnyURL {
    /// Guesses a publication title from a list of resource HREFs.
    ///
    /// If the HREFs contain a single root directory, we assume it is the
    /// title. This is often the case for example with CBZ files.
    func guessTitle() -> String? {
        var title: String?

        for url in self {
            let segments = url.pathSegments
            guard
                segments.count > 1,
                title == nil || title == segments.first
            else {
                return nil
            }
            title = segments.first
        }

        return title
    }
}
