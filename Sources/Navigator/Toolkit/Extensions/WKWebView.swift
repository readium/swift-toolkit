//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import WebKit

extension WKWebView {
    /// Removes the native double-tap gesture from the `WKWebView`.
    ///
    /// This needs to be called every time the web view navigates, in
    /// `WKNavigationDelegate.webView(_:didFinish:)`
    ///
    /// Inspired by https://stackoverflow.com/a/42939172/1474476
    func removeDoubleTapGestureRecognizer() {
        for subview in scrollView.subviews {
            for recognizer in subview.gestureRecognizers ?? [] {
                if
                    let tapRecognizer = recognizer as? UITapGestureRecognizer,
                    tapRecognizer.numberOfTapsRequired == 2,
                    tapRecognizer.numberOfTouchesRequired == 1
                {
                    subview.removeGestureRecognizer(tapRecognizer)
                }
            }
        }
    }
}
