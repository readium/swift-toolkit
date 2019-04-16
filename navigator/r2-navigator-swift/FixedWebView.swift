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
final class FixedWebView: WebView {
    
    /// Dimensions of the document reported in the `viewport` meta tag.
    private var pageSize: CGSize?
    /// Current zoom scale needed to fit the page entirely into the viewport.
    private var pageScale: CGFloat = 0
    
    override var jsEvents: [String : (Any) -> Void] {
        var events = super.jsEvents
        events["pageSize"] = pageSizeDidChange
        return events
    }

    override func setupWebView() {
        super.setupWebView()
        
        // Used to center the web view's content. Since the web view is centered by changing its frame directly, unclipping its bounds allows to see the overflowing content when zooming in.
        webView.clipsToBounds = false
        scrollView.clipsToBounds = false
        clipsToBounds = true
        
        // Required to have the page centered when zooming out. It also feels more natural.
        scrollView.bounces = true
        
        // Script that will report the page size declared in the `viewport` meta tag, once the document is loaded.
        let pageSizeScript = WKUserScript(source: """
            (function() {
              const viewport = document.querySelector('meta[name=viewport]');
              if (viewport) {
                const regex = /(\\w+) *= *([^\\s,]+)/g
                var properties = {};
                var match;
                while (match = regex.exec(viewport.content)) {
                  properties[match[1]] = match[2];
                }
                const width = Number.parseFloat(properties.width);
                const height = Number.parseFloat(properties.height);
                if (width && height) {
                  webkit.messageHandlers.pageSize.postMessage({width, height});
                }
              }
            })();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(pageSizeScript)
    }
    
    // Called by the script reading the page size in the `viewport` meta tag.
    func pageSizeDidChange(body: Any) {
        guard let body = body as? [String: Any],
            let width = body["width"] as? Double,
            let height = body["height"] as? Double else
        {
            pageSize = nil
            return
        }
        
        pageSize = CGSize(width: width, height: height)
        layoutPage()
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
    
    /// Layouts the document to fit its content in the bounds.
    private func layoutPage() {
        guard let pageSize = pageSize else {
            return
        }
        
        // Insets the bounds by the notch area (eg. iPhone X) to make sure that the content is not overlapped by the screen notch.
        let maxSize = bounds.inset(by: notchAreaInsets).size

        // Calculates the zoom scale required to fit the content to the bounds.
        let widthRatio = maxSize.width / pageSize.width
        let heightRatio = maxSize.height / pageSize.height
        let scale = min(widthRatio, heightRatio)
        guard pageScale != scale else {
            return
        }
        pageScale = scale
        
        // Updates the minimum zoom scale in the `viewport` meta tag.
        webView.evaluateJavaScript("""
            (function() {
                const viewport = document.querySelector('meta[name=viewport]');
                if (!viewport) {
                    viewport = document.createElement('meta');
                    viewport.setAttribute('name', 'viewport');
                    document.head.appendChild(viewport);
                }
                viewport.content = 'width=\(pageSize.width), height=\(pageSize.height), initial-scale=\(scale), minimum-scale=\(scale)';
            })();
        """) { _, _ in
            // Setting `initial-scale` in the meta tag should be enough to automatically zoom out the content, but sometimes it doesn't work. This hack will attempt to zoom out the content as soon as the minimumZoomScale reaches the scale calculated earlier.
            func zoomOut(attempts: Int = 20) {
                guard attempts > 0 else {
                    return
                }
                // The scale looses precision after being set in the `viewport` meta tag, so we compare only the first decimals.
                guard Double(round(100 * self.scrollView.minimumZoomScale)/100) == Double(round(100 * scale)/100) else {
                    // The viewport tag was not taken into account yet, we try again in 100ms.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        zoomOut(attempts: attempts - 1)
                    }
                    return
                }
                
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
            }
            zoomOut()
        }
    }

    override func scrollViewDidZoom(_ scrollView: UIScrollView) {
        super.scrollViewDidZoom(scrollView)
        
        // Moves the web view to center its content when the zoom scale changes.
        // We don't use contentInset to center the content because it introduces a few scrolling bugs.
        if let pageSize = pageSize {
            let scale = max(scrollView.minimumZoomScale, scrollView.zoomScale)
            var frame = webView.frame
            frame.origin.x = max(0, (frame.width - pageSize.width * scale) / 2)
            frame.origin.y = max(0, (frame.height - pageSize.height * scale) / 2)
            webView.frame = frame
        }
    }
    
    override func applyUserSettingsStyle() {
        super.applyUserSettingsStyle()

        // Scheduled to make sure that the superview's background-color is also updated.
        DispatchQueue.main.async(execute: updateBackgroundColor)
    }
    
    
    /// The body's background-color leaks out of the body's bounds if no background-color (or a transparent one) is set on the <html> tag. This is part of the HTML specification. To fix this, we have to set the <html> background to the background of the reader. For that, we iterate the superview until we find a background-color to use.
    private func updateBackgroundColor() {
        guard let superview = superview else {
            return
        }

        func findBackgroundColor(of view: UIView) -> UIColor {
            if let color = view.backgroundColor, color != .clear {
                return color
            } else if let superview = view.superview {
                return findBackgroundColor(of: superview)
            } else {
                return .white
            }
        }
        
        let color = findBackgroundColor(of: superview)
        if let colorHex = color.hexString(includingAlpha: false) {
            backgroundColor = color
            
            // The body's background color is also set in case it is transparent, otherwise it would take the color of the superview.
            webView.evaluateJavaScript("""
                document.documentElement.style.setProperty("background-color", "#\(colorHex)", "important")
                if (window.getComputedStyle(document.body).getPropertyValue("background-color") == "rgba(0, 0, 0, 0)") {
                  document.body.style.setProperty("background-color", "white");
                }
            """)
        }
    }

}
