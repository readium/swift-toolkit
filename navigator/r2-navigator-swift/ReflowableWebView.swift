//
//  ReflowableWebView.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 09.04.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


/// A WebView subclass to handle documents with a reflowable layout.
final class ReflowableWebView: WebView {
    
    override func setupWebView() {
        super.setupWebView()
        scrollView.bounces = false
        scrollView.isPagingEnabled = true
    }
    
    override func applyUserSettingsStyle() {
        super.applyUserSettingsStyle()
        
        // Disables paginated mode if scroll is on.
        if let userSettings = userSettings, let scroll = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable {
            scrollView.isPagingEnabled = !scroll.on
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        // Disables zooming.
        return nil
    }
    
}
