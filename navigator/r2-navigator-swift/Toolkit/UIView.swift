//
//  UIView.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 15.04.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit


extension UIView {
    
    /// Returns the safe area insets taking only into account the device screen notches (eg. on iPhone X), ignoring any UX safe area insets (eg. status bar, navigation bar).
    /// This can be used to layout the content in a way that makes sure it's not under the physical notches, but at the same time is under the status and navigation bars (which is usually what we want for a reader app).
    /// We use that instead of pinning the content directly to the safe area layout guides to avoid the view shifting when the status bar is toggled.
    var notchAreaInsets: UIEdgeInsets {
        guard #available(iOS 11.0, *) else {
            return .zero
        }
        
        var windowSafeAreaInsets = window?.safeAreaInsets ?? safeAreaInsets
        
        // Trick to ignore the status bar on devices without notches (pre iPhone X). In this case it is usually 20pts tall (except in some edge cases, eg. during a phone call, but the worst that could happen is that the page is slightly shifted).
        let statusBarSize = UIApplication.shared.statusBarFrame.size
        // The frame is in the coordinate space of the window, so it might be swapped in landscape.
        let statusBarHeight = min(statusBarSize.width, statusBarSize.height)
        if statusBarHeight == 20 && windowSafeAreaInsets.top == statusBarHeight {
            windowSafeAreaInsets.top = 0
        }
        
        // We take the smallest value between the view's safeAreaInsets and the window's safeAreaInsets in case the view is not pinned to the screen edges. In which case, its safeAreaInsets will likely be empty and we don't want to take into account the screen notch.
        return UIEdgeInsets(
            top: min(windowSafeAreaInsets.top, safeAreaInsets.top),
            left: min(windowSafeAreaInsets.left, safeAreaInsets.left),
            bottom: min(windowSafeAreaInsets.bottom, safeAreaInsets.bottom),
            right: min(windowSafeAreaInsets.right, safeAreaInsets.right)
        )
    }
    
}
