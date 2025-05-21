//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import MBProgressHUD
import UIKit

/// Displays the given text in the view for the given duration.
func toast(_ text: String, on view: UIView, duration: TimeInterval) {
    let hud = MBProgressHUD.showAdded(to: view, animated: true)
    hud.mode = .text
    hud.label.text = text
    hud.hide(animated: true, afterDelay: duration)
}

/// Displays an activity indicator in the view.
///
/// - Returns: A closure to be called when the toast needs to be hidden.
func toastActivity(on view: UIView) -> () -> Void {
    let hud = MBProgressHUD.showAdded(to: view, animated: true)
    hud.mode = .indeterminate
    return {
        hud.hide(animated: true)
    }
}
