//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

extension UIView {
    /// Returns the safe area insets taking only into account the device screen notches (eg. on
    /// iPhone X), ignoring any UX safe area insets (eg. status bar, navigation bar).
    ///
    /// This can be used to layout the content in a way that makes sure it's not under the physical
    /// notches, but at the same time is under the status and navigation bars (which is usually what
    /// we want for a reader app).
    ///
    /// We use that instead of pinning the content directly to the safe area layout guides to avoid
    /// the view shifting when the status bar is toggled.
    var notchAreaInsets: UIEdgeInsets {
        guard let window = window else {
            return safeAreaInsets
        }

        var windowSafeAreaInsets = window.safeAreaInsets

        // Trick to ignore the status bar on devices without notches (pre iPhone X).
        // Notch height is usually at least 44pts tall.
        let statusBarSize = window.windowScene?.statusBarManager?.statusBarFrame.size ?? .zero
        // The frame is in the coordinate space of the window, so it might be swapped in landscape.
        let statusBarHeight = min(statusBarSize.width, statusBarSize.height)
        if statusBarHeight < 44, windowSafeAreaInsets.top == statusBarHeight {
            windowSafeAreaInsets.top = 0
        }

        // We take the smallest value between the view's safeAreaInsets and the window's
        // safeAreaInsets in case the view is not pinned to the screen edges. In which case, its
        // safeAreaInsets will likely be empty and we don't want to take into account the screen
        // notch.
        return UIEdgeInsets(
            top: min(windowSafeAreaInsets.top, safeAreaInsets.top),
            left: min(windowSafeAreaInsets.left, safeAreaInsets.left),
            bottom: min(windowSafeAreaInsets.bottom, safeAreaInsets.bottom),
            right: min(windowSafeAreaInsets.right, safeAreaInsets.right)
        )
    }

    // Finds the first `UIScrollView` in the view hierarchy.
    //
    // https://medium.com/@wailord/the-particulars-of-the-safe-area-and-contentinsetadjustmentbehavior-in-ios-11-9b842018eeaa#077b
    var firstScrollView: UIScrollView? {
        sequence(first: self) { $0.subviews.first }
            .first { $0 is UIScrollView }
            as? UIScrollView
    }
}
