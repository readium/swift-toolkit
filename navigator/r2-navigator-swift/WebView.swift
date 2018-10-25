//
//  WebView.swift
//  r2-navigator-swift
//
//  Created by Winnie Quinn, Alexandre Camilleri on 8/23/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import WebKit

import R2Shared

protocol ViewDelegate: class {
    func displayRightDocument()
    func displayLeftDocument()
    func handleCenterTap()
    func publicationIdentifier() -> String?
    func publicationBaseUrl() -> URL?
    func handleTapOnLink(with url: URL)
    func handleTapOnInternalLink(with href: String)
    func documentPageDidChanged(webview: WebView, currentPage: Int ,totalPage: Int)
}

final class WebView: WKWebView {

    public weak var viewDelegate: ViewDelegate?
    fileprivate let initialLocation: BinaryLocation
    
    var direction: PageProgressionDirection?

    public var initialId: String?
    // progression and totalPages only work on 'readium-scroll-off' mode
    public var progression: Double?
    public var totalPages: Int?
    public func currentPage() -> Int {
        guard progression != nil && totalPages != nil else {
            return 1
        }
        return Int(progression! * Double(totalPages!)) + 1
    }
    
    internal var userSettings: UserSettings?

    public var documentLoaded = false

    public var presentingFixedLayoutContent = false // TMP fix for fxl.

    var hasLoadedJsEvents = false
    let jsEvents = ["leftTap": leftTapped,
                    "centerTap": centerTapped,
                    "rightTap": rightTapped,
                    "didLoad": documentDidLoad,
                    "updateProgression": progressionDidChange]
    
    let jsFollowUp = ["leftTap": dismissIfNeed,
                    "centerTap": dismissIfNeed,
                    "rightTap": dismissIfNeed]

    internal enum Scroll {
        case left
        case right
        func proceed(on target: WebView) {
            
            let scrollView = target.scrollView
            if scrollView.isPagingEnabled {
                switch self {
                case .left:
                    let isAtFirstPageInDocument = scrollView.contentOffset.x == 0
                    if !isAtFirstPageInDocument { return scrollView.scrollToPreviousPage() }
                case .right:
                    let isAtLastPageInDocument = scrollView.contentOffset.x == scrollView.contentSize.width - scrollView.frame.size.width
                    if !isAtLastPageInDocument { return scrollView.scrollToNextPage() }
                }
            }
            
            let dir = target.direction?.rawValue ?? PageProgressionDirection.ltr.rawValue
            
            switch self {
            case .left:
                target.evaluateJavaScript("scrollLeft(\"\(dir)\");", completionHandler: { result, error in
                    if error == nil, let result = result as? String, result == "edge" {
                        target.viewDelegate?.displayLeftDocument()
                    }
                })
            case .right:
                target.evaluateJavaScript("scrollRight(\"\(dir)\");", completionHandler: { result, error in
                    if error == nil, let result = result as? String, result == "edge" {
                        target.viewDelegate?.displayRightDocument()
                    }
                })
            }
        }
    }
    
    var sizeObservation: NSKeyValueObservation?

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
        uiDelegate = self
        
        sizeObservation = scrollView.observe(\.contentSize, options: .new) { (thisScrollView, thisValue) in
            // update total pages
            guard self.documentLoaded else { return }
            guard let newWidth = thisValue.newValue?.width else {return}
            let pageWidth = self.scrollView.frame.size.width
            if pageWidth == 0.0 {return} // Possible zero value
            let pageCount = Int(newWidth / self.scrollView.frame.size.width);
            if self.totalPages != pageCount {
                self.totalPages = pageCount
                self.viewDelegate?.documentPageDidChanged(webview: self, currentPage: self.currentPage(), totalPage: pageCount)
            }
        }
        
        self.alpha = 0
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
    
    internal func dismissIfNeed() {
        self.isUserInteractionEnabled = false
        self.isUserInteractionEnabled = true
    }

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
        
        fadeInWithDelay()
        
        applyUserSettingsStyle()
        scrollToInitialPosition()
    }
}

extension WebView {
    // Scroll at position 0-1 (0%-100%)
    internal func scrollAt(position: Double) {
        guard position >= 0 && position <= 1 else { return }
        
        let dir = self.direction?.rawValue ?? PageProgressionDirection.ltr.rawValue

        self.evaluateJavaScript("scrollToPosition(\'\(position)\', \'\(dir)\')",
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
        case .left:
            scrollAt(position: 0)
        case .right:
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
        
        let originPage = self.currentPage()

        progression = newProgression
        
        let currentPage = self.currentPage()
        
        if originPage != currentPage {
            if let pages = totalPages {
                viewDelegate?.documentPageDidChanged(webview: self, currentPage: currentPage, totalPage: pages)
            }
        }
    }

    /// Update webview style to userSettings.
    internal func applyUserSettingsStyle() {
        guard let userSettings = userSettings else {
            return
        }
        for cssProperty in userSettings.userProperties.properties {
            evaluateJavaScript("setProperty(\"\(cssProperty.name)\", \"\(cssProperty.toString())\");", completionHandler: nil)
        }
        // Disable paginated mode if scroll is on.
        if let scroll = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable {
            scrollView.isPagingEnabled = !scroll.on
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
        if let followup = jsFollowUp[message.name] {
            followup(self)()
        }
    }

    /// Add a message handler for incoming javascript events.
    internal func addMessageHandlers() {
        if hasLoadedJsEvents { return }
        // Add the message handlers.
        for eventName in jsEvents.keys {
            configuration.userContentController.add(self, name: eventName)
        }
        hasLoadedJsEvents = true
    }

    // Deinit message handlers (preventing strong reference cycle).
    internal func removeMessageHandlers() {
        for eventName in jsEvents.keys {
            configuration.userContentController.removeScriptMessageHandler(forName: eventName)
        }
        hasLoadedJsEvents = false
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
                    viewDelegate?.handleTapOnInternalLink(with: href)
                } else {
                    viewDelegate?.handleTapOnLink(with: url)
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

extension WebView: WKUIDelegate {
    
    
    @available(iOS 10.0, *) //the property allowsLinkPreview is default false in iOS9, so this should be safe
    func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        let publicationBaseUrl = viewDelegate?.publicationBaseUrl()
        let url = elementInfo.linkURL
        if url?.host == publicationBaseUrl?.host {
            return false
        }
        return true
    }
}


private extension UIScrollView {
    
    func scrollToNextPage() {
        moveHorizontalContent(with: bounds.size.width)
    }
    
    func scrollToPreviousPage() {
        moveHorizontalContent(with: -bounds.size.width)
    }
    
    private func moveHorizontalContent(with offsetX: CGFloat) {
        var newOffset = contentOffset
        newOffset.x += offsetX
        let rounded = round(newOffset.x / offsetX) * offsetX
        newOffset.x = rounded
        let area = CGRect.init(origin: newOffset, size: bounds.size)
        scrollRectToVisible(area, animated: true)
    }
}

private extension UIView {
    
    func fadeInWithDelay() {
        //We need to give the CSS and webview time to layout correctly. :( 0.2 seconds seems like a good value for it to work on an iPhone 5s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 1
            })
        }
    }
}

