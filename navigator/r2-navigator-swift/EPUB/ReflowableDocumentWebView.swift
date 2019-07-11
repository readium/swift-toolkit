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
final class ReflowableDocumentWebView: DocumentWebView {

    private var topConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!

    override func setupWebView() {
        super.setupWebView()
        scrollView.bounces = false
        scrollView.isPagingEnabled = !isScrollEnabled
        
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
        
        if let properties = userSettings?.userProperties.properties {
            let propertiesScript = properties.reduce("") { script, property in
                let value: String = {
                    // Scroll mode depends both on the user settings, and on the fact that VoiceOver is activated or not, so we need to generate the value dynamically.
                    // FIXME: This would be handled in a better way by decoupling the user settings from the actual ReadiumCSS properties sent to the WebView, which should be private details of the EPUBNavigator implementation and not shared with the host app.
                    if let switchable = property as? Switchable, property.name == ReadiumCSSName.scroll.rawValue {
                        return switchable.values[isScrollEnabled]!
                    } else {
                        return property.toString()
                    }
                }()
                return script + "readium.setProperty(\"\(property.name)\", \"\(value)\");\n"
            }
            evaluateScriptInResource(propertiesScript)
        }

        // Disables paginated mode if scroll is on.
        scrollView.isPagingEnabled = !isScrollEnabled
        
        updateContentInset()
    }

    private func updateContentInset() {
        if (isScrollEnabled) {
            topConstraint.constant = 0
            bottomConstraint.constant = 0
            scrollView.contentInset = UIEdgeInsets(top: notchAreaInsets.top, left: 0, bottom: notchAreaInsets.bottom, right: 0)
            
        } else {
            var insets = contentInset[traitCollection.verticalSizeClass]
                ?? contentInset[.regular]
                ?? contentInset[.unspecified]
                ?? (top: 0, bottom: 0)
            
            // Increases the insets by the notch area (eg. iPhone X) to make sure that the content is not overlapped by the screen notch.
            insets.top += notchAreaInsets.top
            insets.bottom += notchAreaInsets.bottom
            
            topConstraint.constant = insets.top
            bottomConstraint.constant = -insets.bottom
            scrollView.contentInset = .zero
        }
    }
    
    override func pointFromTap(_ data: [String : Any]) -> CGPoint? {
        guard let x = data["clientX"] as? Int, let y = data["clientY"] as? Int else {
            return nil
        }
        
        var point = CGPoint(x: x, y: y)
        if isScrollEnabled {
            // Starting from iOS 12, the contentInset are not taken into account in the JS touch event.
            if #available(iOS 12.0, *) {
                if scrollView.contentOffset.x < 0 {
                    point.x += abs(scrollView.contentOffset.x)
                }
                if scrollView.contentOffset.y < 0 {
                    point.y += abs(scrollView.contentOffset.y)
                }
            } else {
                point.x += scrollView.contentInset.left
                point.y += scrollView.contentInset.top
            }
        }
        point.x += webView.frame.minX
        point.y += webView.frame.minY
        return point
    }
    
    
    // MARK: Scripts
    
    private static let cssScript = loadScript(named: "css")
    private static let cssInlineScript = loadScript(named: "css-inline")
    
    override func makeScripts() -> [WKUserScript] {
        var scripts = super.makeScripts()
        
        // Setups the `viewport` meta tag to disable zooming.
        scripts.append(WKUserScript(source: """
            (function() {
              var meta = document.createElement("meta");
              meta.setAttribute("name", "viewport");
              meta.setAttribute("content", "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no");
              document.head.appendChild(meta);
            })();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        // Injects ReadiumCSS stylesheets.
        if let resourcesURL = resourcesURL {
            // When a publication is served from an HTTPS server, then WKWebView forbids accessing the stylesheets from the local, unsecured GCDWebServer instance. In this case we will inject directly the full content of the CSS in the JavaScript.
            if baseURL.scheme?.lowercased() == "https" {
                func loadCSS(_ name: String) -> String? {
                    return loadResource(at: "styles/\(contentLayout.rawValue)/\(name).css")?
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "`", with: "\\`")
                }
                
                if let cssScript = ReflowableDocumentWebView.cssInlineScript,
                    let beforeCSS = loadCSS("ReadiumCSS-before"),
                    let afterCSS = loadCSS("ReadiumCSS-after") {
                    scripts.append(WKUserScript(
                        source: cssScript
                            .replacingOccurrences(of: "${css-before}", with: beforeCSS)
                            .replacingOccurrences(of: "${css-after}", with: afterCSS),
                        injectionTime: .atDocumentStart,
                        forMainFrameOnly: false
                    ))
                }
                
            } else {
                if let cssScript = ReflowableDocumentWebView.cssScript {
                    scripts.append(WKUserScript(
                        source: cssScript
                            .replacingOccurrences(of: "${resourcesURL}", with: resourcesURL.absoluteString)
                            .replacingOccurrences(of: "${contentLayout}", with: contentLayout.rawValue),
                        injectionTime: .atDocumentStart,
                        forMainFrameOnly: false
                    ))
                }
            }
        }
        
        return scripts
    }

}
