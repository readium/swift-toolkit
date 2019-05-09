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
import WebKit
import R2Shared


/// A WebView subclass to handle documents with a reflowable layout.
final class ReflowableWebView: WebView {

    private var topConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!

    override func setupWebView() {
        super.setupWebView()
        scrollView.bounces = false
        scrollView.isPagingEnabled = true
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        topConstraint = webView.topAnchor.constraint(equalTo: topAnchor)
        topConstraint.priority = .defaultHigh
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            topConstraint, bottomConstraint,
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        // Setups the `viewport` meta tag to disable zooming.
        let viewportScript = WKUserScript(source: """
            (function() {
              var meta = document.createElement("meta");
              meta.setAttribute("name", "viewport");
              meta.setAttribute("content", "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no");
              document.head.appendChild(meta);
            })();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(viewportScript)
    }
    
    @available(iOS 11.0, *)
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateContentInset()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContentInset()
    }

    override func applyUserSettingsStyle() {
        super.applyUserSettingsStyle()
        
        if let userSettings = userSettings {
            for cssProperty in userSettings.userProperties.properties {
                evaluateScriptInResource("setProperty(\"\(cssProperty.name)\", \"\(cssProperty.toString())\");")
            }
        }

        // Disables paginated mode if scroll is on.
        scrollView.isPagingEnabled = !isScrollEnabled
        
        updateContentInset()
    }

    private func updateContentInset() {
        var insets = contentInset[traitCollection.verticalSizeClass]
            ?? contentInset[.regular]
            ?? contentInset[.unspecified]
            ?? (top: 0, bottom: 0)
        
        // Increases the insets by the notch area (eg. iPhone X) to make sure that the content is not overlapped by the screen notch.
        insets.top += notchAreaInsets.top
        insets.bottom += notchAreaInsets.bottom

        if (isScrollEnabled) {
            topConstraint.constant = 0
            bottomConstraint.constant = 0
            scrollView.contentInset = UIEdgeInsets(top: insets.top, left: 0, bottom: insets.bottom, right: 0)
        } else {
            topConstraint.constant = insets.top
            bottomConstraint.constant = -insets.bottom
            scrollView.contentInset = .zero
        }
    }

}
