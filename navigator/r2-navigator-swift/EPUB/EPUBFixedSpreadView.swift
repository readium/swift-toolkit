//
//  EPUBFixedSpreadView.swift
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


/// A view rendering a spread of resources with a fixed layout.
final class EPUBFixedSpreadView: EPUBSpreadView {
    
    /// Whether the host wrapper page is loaded or not. The wrapper page contains the iframe that will display the resource.
    private var isWrapperLoaded = false
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
        let spreadFile = "fxl-spread-\(spread.pageCount.rawValue)"
        if let wrapperPageURL = Bundle(for: type(of: self)).url(forResource: spreadFile, withExtension: "html"), let wrapperPage = try? String(contentsOf: wrapperPageURL, encoding: .utf8) {
            // The publication's base URL is used to make sure we can access the resources through the iframe with JavaScript.
            webView.loadHTMLString(wrapperPage, baseURL: publication.baseURL)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSpread()
    }
    
    @available(iOS 11.0, *)
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        layoutSpread()
    }
    
    override func loadSpread() {
        guard isWrapperLoaded else {
            return
        }
        webView.evaluateJavaScript("spread.load(\(spread.jsonString(for: publication)));")
    }

    /// Layouts the resource to fit its content in the bounds.
    private func layoutSpread() {
        guard isWrapperLoaded else {
            return
        }
        // Insets the bounds by the notch area (eg. iPhone X) to make sure that the content is not overlapped by the screen notch.
        let insets = notchAreaInsets
        let viewportSize = bounds.inset(by: insets).size
        
        webView.evaluateJavaScript("""
            spread.setViewport(
              {'width': \(Int(viewportSize.width)), 'height': \(Int(viewportSize.height))},
              {'top': \(Int(insets.top)), 'left': \(Int(insets.left)), 'bottom': \(Int(insets.bottom)), 'right': \(Int(insets.right))}
            );
        """)
    }
    
    override func pointFromTap(_ data: TapData) -> CGPoint? {
        let x = data.screenX
        let y = data.screenY

        return CGPoint(
            x: CGFloat(x) * scrollView.zoomScale - scrollView.contentOffset.x + webView.frame.minX,
            y: CGFloat(y) * scrollView.zoomScale - scrollView.contentOffset.y + webView.frame.minY
        )
    }
    
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)
        
        if !isWrapperLoaded {
            isWrapperLoaded = true
            layoutSpread()
            loadSpread()
        }
    }
    
    
    /// MARK: - Scripts
    
    private static let fixedScript = loadScript(named: "fixed")
    
    override func makeScripts() -> [WKUserScript] {
        var scripts = super.makeScripts()
        scripts.append(WKUserScript(source: EPUBFixedSpreadView.fixedScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        return scripts
    }

}
