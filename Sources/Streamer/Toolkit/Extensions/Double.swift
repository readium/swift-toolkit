//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Double {
    /// Returns this number when it is finite and greater than 0.
    func orNilIfNotPositive() -> Double? {
        isFinite && self > 0 ? self : nil
    }
}
