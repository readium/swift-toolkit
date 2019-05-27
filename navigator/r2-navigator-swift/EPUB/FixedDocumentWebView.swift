//
//  FixedWebView.swift
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


/// A WebView subclass to handle documents with a fixed layout.
final class FixedDocumentWebView: DocumentWebView {
    
    /// Whether the host wrapper page is loaded or not. The wrapper page contains the iframe that will display the resource.
    private var isWrapperPageLoaded = false
    /// URL to load in the iframe once the wrapper page is loaded.
    private var urlToLoad: URL?
    
    override func setupWebView() {
        super.setupWebView()
        
        // Used to center the web view's content. Since the web view is centered by changing its frame directly, unclipping its bounds allows to see the overflowing content when zooming in.
        webView.clipsToBounds = false
        scrollView.clipsToBounds = false
        clipsToBounds = true
        
        // Required to have the page centered when zooming out. It also feels more natural.
        scrollView.bounces = true
        
        // Makes sure that we can see the superview's background color behind the iframe.
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        scrollView.backgroundColor = UIColor.clear
        
        // Loads the wrapper page into the web view.
        if let wrapperPageURL = Bundle(for: type(of: self)).url(forResource: "fxl-wrapper", withExtension: "html"), let wrapperPage = try? String(contentsOf: wrapperPageURL, encoding: .utf8) {
            // The publication's base URL is used to make sure we can access the resource through the iframe with JavaScript.
            webView.loadHTMLString(wrapperPage, baseURL: baseURL)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutPage()
    }
    
    @available(iOS 11.0, *)
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        layoutPage()
    }
    
    override func load(_ url: URL) {
        guard isWrapperPageLoaded else {
            urlToLoad = url
            return
        }
        webView.evaluateJavaScript("page.load('\(url)');")
    }
    
    override func evaluateScriptInResource(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        guard isWrapperPageLoaded else {
            completion?(nil, nil)
            return
        }
        let script = "page.eval(\"\(script.replacingOccurrences(of: "\"", with: "\\\""))\");"
        super.evaluateScriptInResource(script, completion: completion)
    }
    
    /// Layouts the resource to fit its content in the bounds.
    private func layoutPage() {
        guard isWrapperPageLoaded else {
            return
        }
        // Insets the bounds by the notch area (eg. iPhone X) to make sure that the content is not overlapped by the screen notch.
        let insets = notchAreaInsets
        let viewportSize = bounds.inset(by: insets).size
        
        webView.evaluateJavaScript("""
            page.setViewport(
              {'width': \(Int(viewportSize.width)), 'height': \(Int(viewportSize.height))},
              {'top': \(Int(insets.top)), 'left': \(Int(insets.left)), 'bottom': \(Int(insets.bottom)), 'right': \(Int(insets.right))}
            );
        """)
    }
    
    override func pointFromTap(_ data: [String : Any]) -> CGPoint? {
        guard let x = data["screenX"] as? Int, let y = data["screenY"] as? Int else {
            return nil
        }

        return CGPoint(
            x: CGFloat(x) * scrollView.zoomScale - scrollView.contentOffset.x + webView.frame.minX,
            y: CGFloat(y) * scrollView.zoomScale - scrollView.contentOffset.y + webView.frame.minY
        )
    }
    
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)
        
        if !isWrapperPageLoaded {
            isWrapperPageLoaded = true
            layoutPage()
            if let url = urlToLoad {
                urlToLoad = nil
                load(url)
            }
        }
    }

}
