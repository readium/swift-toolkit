//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

extension UIViewController {
    /// The top-most presented view controller in the app's key window, if any.
    static var topMost: UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        guard var top = keyWindow?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

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
