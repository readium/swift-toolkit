//
//  WebView.swift
//  r2-navigator-swift
//
//  Created by Winnie Quinn, Alexandre Camilleri on 8/23/17.
//  Copyright © 2017 Readium.
//  This file is covered by the LICENSE file in the root of this project.
//

import WebKit
import SafariServices

protocol ViewDelegate: class {
    func displayNextDocument()
    func displayPreviousDocument()
    func handleCenterTap()
    func publicationIdentifier() -> String?
    func publicationBaseUrl() -> URL?
    func displaySpineItem(with href: String)
}

final class WebView: WKWebView {

    public weak var viewDelegate: ViewDelegate?
    fileprivate let initialLocation: BinaryLocation

    public var initialId: String?
    public var progression: Double?
    internal var userSettings: UserSettings?

    public var documentLoaded = false

    public var presentingFixedLayoutContent = false // TMP fix for fxl.

    let jsEvents = ["leftTap": leftTapped,
                    "centerTap": centerTapped,
                    "rightTap": rightTapped,
                    "didLoad": documentDidLoad,
                    "updateProgression": progressionDidChange]

    internal enum Scroll {
        case left
        case right

        func proceed(on target: WebView) {
            switch self {
            case .left:
                target.evaluateJavaScript("scrollLeft();", completionHandler: { result, error in
                    if error == nil, let result = result as? String, result == "edge" {
                        target.viewDelegate?.displayPreviousDocument()
                    }
                })
            case .right:
                target.evaluateJavaScript("scrollRight();", completionHandler: { result, error in
                    if error == nil, let result = result as? String, result == "edge" {
                        target.viewDelegate?.displayNextDocument()
                    }
                })
            }
        }
    }

    init(frame: CGRect, initialLocation: BinaryLocation) {
        self.initialLocation = initialLocation
        super.init(frame: frame, configuration: .init())

        isOpaque = false
        backgroundColor = UIColor.clear
        scrollView.backgroundColor = UIColor.clear
        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        navigationDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        // Fixing an iOS 9 bug by explicitly clearing scrollView.delegate before deinitialization
        if superview == nil {
            scrollView.delegate = nil
        }
        else {
            scrollView.delegate = self
        }
    }
}

extension WebView {

    /// Called from the JS code when a tap is detected in the 2/10 left
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    internal func leftTapped(body: String) {
        // Verify that the document is properly loaded.
        guard documentLoaded else {
            return
        }
        Scroll.left.proceed(on: self)
    }

    /// Called from the JS code when a tap is detected in the 2/10 right
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    internal func rightTapped(body: String) {
        // Verify that the document is properly loaded.
        guard documentLoaded else {
            return
        }
        Scroll.right.proceed(on: self)
    }

    /// Called from the JS code when a tap is detected in the 6/10 center
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    internal func centerTapped(body: String) {
        viewDelegate?.handleCenterTap()
    }

    /// Called by the javascript code to notify on DocumentReady.
    ///
    /// - Parameter body: Unused.
    internal func documentDidLoad(body: String) {
        documentLoaded = true
        scrollToInitialPosition()
        applyUserSettingsStyle()
    }
}

extension WebView {
    // Scroll at position 0-1 (0%-100%)
    internal func scrollAt(position: Double) {
        guard position >= 0 && position <= 1 else { return }

        self.evaluateJavaScript("scrollToPosition(\'\(position)\')",
            completionHandler: nil)
    }

    // Scroll at the tag with id `tagId`.
    internal func scrollAt(tagId: String) {
        evaluateJavaScript("scrollToId(\'\(tagId)\');",
            completionHandler: nil)
    }

    // Scroll to .beggining or .end.
    internal func scrollAt(location: BinaryLocation) {
        switch location {
        case .beginning:
            scrollAt(position: 0)
        case .end:
            scrollAt(position: 1)
        }
    }

    /// Moves the webView to the initial location.
    fileprivate func scrollToInitialPosition() {

        /// If the savedProgression property has been set by the navigator.
        if let initialPosition = progression, initialPosition > 0.0 {
            scrollAt(position: initialPosition)
        } else if let initialId = initialId {
            scrollAt(tagId: initialId)
        } else {
            scrollAt(location: initialLocation)
        }
    }

    // Called by the javascript code to notify that scrolling ended.
    internal func progressionDidChange(body: String) {
        guard documentLoaded, let newProgression = Double(body) else {
            return
        }
        progression = newProgression
    }

    /// Update webview style to userSettings.
    internal func applyUserSettingsStyle() {
        guard let userSettings = userSettings else {
            return
        }
        for cssProperty in userSettings.cssProperties() {
            evaluateJavaScript("setProperty(\"\(cssProperty.key)\", \"\(cssProperty.value)\");",
                completionHandler: nil)
        }
        // Disable paginated mode if scroll is on.
        if let scroll = userSettings.scroll {
            scrollView.isPagingEnabled = !scroll.bool()
        }
    }
}

// MARK: - WKScriptMessageHandler for handling incoming message from the Bridge.js
// javascript code.
extension WebView: WKScriptMessageHandler {

    // Handles incoming calls from JS.
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else {
            return
        }
        if let handler = jsEvents[message.name] {
            handler(self)(body)
        }
    }

    /// Add a message handler for incoming javascript events.
    internal func addMessageHandlers() {
        // Add the message handlers.
        for eventName in jsEvents.keys {
            configuration.userContentController.add(self, name: eventName)
        }
    }

    // Deinit message handlers (preventing strong reference cycle).
    internal func removeMessageHandlers() {
        for eventName in jsEvents.keys {
            configuration.userContentController.removeScriptMessageHandler(forName: eventName)
        }
    }
}

extension WebView: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let navigationType = navigationAction.navigationType

        if navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                // TO/DO add URL normalisation.
                //check url if internal or external
                let publicationBaseUrl = viewDelegate?.publicationBaseUrl()

                if url.host == publicationBaseUrl?.host,
                    let baseUrlString = publicationBaseUrl?.absoluteString {
                    // Internal link.
                    let href = url.absoluteString.replacingOccurrences(of: baseUrlString, with: "")

                    viewDelegate?.displaySpineItem(with: href)
                } else if url.absoluteString.contains("http") { // TEMPORARY, better checks coming.
                    // External Link.
                    let view = SFSafariViewController(url: url)

                    UIApplication.shared.keyWindow?.rootViewController?.present(view,
                                                                                animated: true,
                                                                                completion: nil)
                }
            }
        }

        decisionHandler(navigationType == .other ? .allow : .cancel)
    }
}

extension WebView: UIScrollViewDelegate {
    // IFFXL
    func viewForZooming(in: UIScrollView) -> UIView? {
        if presentingFixedLayoutContent {
            for view in scrollView.subviews { // For FXL tmp
                if let classString = NSClassFromString("WKContentView"), view.isKind(of: classString) {
                    return view
                }
            }// tmp end
        }
        return nil
    }
}

