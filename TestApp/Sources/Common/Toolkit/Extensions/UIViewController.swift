//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

extension UIViewController {
    /// Finds the first child view controller with the given type, recursively.
    func findChildViewController<T: UIViewController>() -> T? {
        for childViewController in children {
            if let found = childViewController as? T {
                return found
            }
            if let found: T = childViewController.findChildViewController() {
                return found
            }
        }
        return nil
    }
}
