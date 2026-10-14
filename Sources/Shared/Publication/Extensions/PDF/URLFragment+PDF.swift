//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// PDF extensions for `URLFragment`.
public extension URLFragment {
    /// Creates a `page=N` fragment targeting the page with the given 1-based
    /// `number` in a PDF document.
    ///
    /// - https://www.rfc-editor.org/rfc/rfc8118#section-3
    static func page(_ number: Int) -> URLFragment {
        URLFragment(rawValue: "page=\(number)")!
    }
}
