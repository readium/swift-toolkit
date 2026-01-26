//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

extension UIView {
    // Finds the first `UIScrollView` in the view hierarchy.
    //
    // https://medium.com/@wailord/the-particulars-of-the-safe-area-and-contentinsetadjustmentbehavior-in-ios-11-9b842018eeaa#077b
    var firstScrollView: UIScrollView? {
        sequence(first: self) { $0.subviews.first }
            .first { $0 is UIScrollView }
            as? UIScrollView
    }
}
