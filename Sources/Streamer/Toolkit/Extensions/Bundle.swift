//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

#if !SWIFT_PACKAGE
extension Bundle {
    /// Returns R2Streamer's bundle by querying an arbitrary type.
    static let module = Bundle(for: Streamer.self)
}
#endif
