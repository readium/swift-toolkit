//
//  EPUBReflowableSpreadView.swift
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


/// A view rendering a spread of resources with a reflowable layout.
final class EPUBReflowableSpreadView: EPUBSpreadView {

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
        
        let properties = userSettings.userProperties.properties
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
        for link in spread.pages {
            evaluateScript(propertiesScript, inResource: link.href)
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
    
    
    /// MARK: - Location
    
    /// Locator to the leading page in the spread.
    override var currentLocation: Locator {
        let link = spread.leading
        return Locator(
            href: link.href,
            type: link.type ?? "text/html",
            locations: Locations(progression: progression ?? 0)
        )
    }
    
    override func go(to direction: EPUBSpreadView.Direction, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        guard !isScrollEnabled else {
            return super.go(to: direction, animated: animated, completion: completion)
        }
        
        let factor: CGFloat = {
            switch direction {
            case .left:
                return -1
            case .right:
                return 1
            }
        }()

        let offsetX = scrollView.bounds.width * factor
        var newOffset = scrollView.contentOffset
        newOffset.x += offsetX
        let rounded = round(newOffset.x / offsetX) * offsetX
        newOffset.x = rounded
        guard 0..<scrollView.contentSize.width ~= newOffset.x else {
            return false
        }
        
        let area = CGRect(origin: newOffset, size: bounds.size)
        if animated {
            delegate?.spreadViewWillAnimate(self)
        }
        scrollView.scrollRectToVisible(area, animated: animated)
        // FIXME: completion needs to be implemented using scroll view delegate
        DispatchQueue.main.async(execute: completion)

        return true
    }
    
    override func goToHref(_ href: String, location: Locations, completion: @escaping () -> Void) {
        // FIXME: check that the fragment is actually a tag ID
        if let id = location.fragment, !id.isEmpty {
            go(toHref: href, tagID: id, completion: completion)
        } else if let progression = location.progression {
            go(toHref: href, progression: progression, completion: completion)
        } else {
            super.goToHref(href, location: location, completion: completion)
        }
    }

    /// Scrolls at given progression (from 0.0 to 1.0)
    private func go(toHref href: String, progression: Double, completion: @escaping () -> Void) {
        guard progression >= 0 && progression <= 1 else {
            log(.warning, "Scrolling to invalid progression \(progression)")
            completion()
            return
        }
        
        // Note: The JS layer does not take into account the scroll view's content inset. So it can't be used to reliably scroll to the top or the bottom of the page in scroll mode.
        if isScrollEnabled && [0, 1].contains(progression) {
            var contentOffset = scrollView.contentOffset
            contentOffset.y = (progression == 0)
                ? -scrollView.contentInset.top
                : (scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
            scrollView.contentOffset = contentOffset
            completion()
        } else {
            let dir = readingProgression.rawValue
            evaluateScript("readium.scrollToPosition(\'\(progression)\', \'\(dir)\')", inResource: href) { _, _ in completion () }
        }
    }
    
    /// Scrolls at the tag with ID `tagID`.
    private func go(toHref href: String, tagID: String, completion: @escaping () -> Void) {
        evaluateScript("readium.scrollToId(\'\(tagID)\');", inResource: href) { _, _ in completion() }
    }
    
    
    // MARK: - Progression
    
    // Current progression in the page.
    private var progression: Double?
    // To check if a progression change was cancelled or not.
    private var previousProgression: Double?
    
    // Called by the javascript code to notify that scrolling ended.
    private func progressionDidChange(body: Any) {
        guard spreadLoaded, let bodyString = body as? String, let newProgression = Double(bodyString) else {
            return
        }
        if previousProgression == nil {
            previousProgression = progression
        }
        progression = newProgression
    }
    
    @objc private func notifyPagesDidChange() {
        guard previousProgression != progression else {
            return
        }
        previousProgression = nil
        delegate?.spreadViewPagesDidChange(self)
    }
    
    
    // MARK: - Scripts
    
    override func registerJSMessages() {
        super.registerJSMessages()
        registerJSMessage(named: "progressionChanged", handler: progressionDidChange)
    }
    
    private static let reflowableScript = loadScript(named: "reflowable")
    private static let cssScript = loadScript(named: "css")
    private static let cssInlineScript = loadScript(named: "css-inline")
    
    override func makeScripts() -> [WKUserScript] {
        var scripts = super.makeScripts()
        
        scripts.append(WKUserScript(source: EPUBReflowableSpreadView.reflowableScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        // Injects ReadiumCSS stylesheets.
        if let resourcesURL = resourcesURL {
            // When a publication is served from an HTTPS server, then WKWebView forbids accessing the stylesheets from the local, unsecured GCDWebServer instance. In this case we will inject directly the full content of the CSS in the JavaScript.
            if publication.baseURL?.scheme?.lowercased() == "https" {
                func loadCSS(_ name: String) -> String {
                    return loadResource(at: "styles/\(contentLayout.rawValue)/\(name).css")
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "`", with: "\\`")
                }
                
                let beforeCSS = loadCSS("ReadiumCSS-before")
                let afterCSS = loadCSS("ReadiumCSS-after")
                scripts.append(WKUserScript(
                    source: EPUBReflowableSpreadView.cssInlineScript
                        .replacingOccurrences(of: "${css-before}", with: beforeCSS)
                        .replacingOccurrences(of: "${css-after}", with: afterCSS),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                ))

            } else {
                scripts.append(WKUserScript(
                    source: EPUBReflowableSpreadView.cssScript
                        .replacingOccurrences(of: "${resourcesURL}", with: resourcesURL.absoluteString)
                        .replacingOccurrences(of: "${contentLayout}", with: contentLayout.rawValue),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                ))
            }
        }
        
        return scripts
    }
    
    
    // MARK: - UIScrollViewDelegate
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        
        // Makes sure we always receive the "ending scroll" event.
        // ie. https://stackoverflow.com/a/1857162/1474476
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(notifyPagesDidChange), object: nil)
        perform(#selector(notifyPagesDidChange), with: nil, afterDelay: 0.3)
    }

}
