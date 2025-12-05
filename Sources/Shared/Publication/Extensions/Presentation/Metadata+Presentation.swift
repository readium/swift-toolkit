//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Presentation extensions for `Metadata`.
public extension Metadata {
    @available(*, unavailable, message: "This was removed from RWPM. You can still use the EPUB extensibility to access the original values.")
    var presentation: Presentation { fatalError() }
}
