//
//  DocumentWebView.swift
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

protocol DocumentWebViewDelegate: class {
    func willAnimatePageChange()
    func didEndPageAnimation()
    @discardableResult
    func displayRightDocument(animated: Bool, completion: @escaping () -> Void) -> Bool
    @discardableResult
    func displayLeftDocument(animated: Bool, completion: @escaping () -> Void) -> Bool
    func webView(_ webView: DocumentWebView, didTapAt point: CGPoint)
    func handleTapOnLink(with url: URL)
    func handleTapOnInternalLink(with href: String)
    func documentPageDidChange(webView: DocumentWebView, currentPage: Int ,totalPage: Int)
}

class DocumentWebView: UIView, Loggable {
    
    weak var viewDelegate: DocumentWebViewDelegate?
    fileprivate let initialLocation: BinaryLocation
    
    let baseURL: URL
    let webView: WebView

    let readingProgression: ReadingProgression

    /// If YES, the content will be fade in once loaded.
    let animatedLoad: Bool
    
    let contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]

    weak var activityIndicatorView: UIActivityIndicatorView?

    var initialId: String?
    var progression: Double?
    var totalPages: Int?
    func currentPage() -> Int {
        guard progression != nil && totalPages != nil else {
            return 1
        }
        return Int(progression! * Double(totalPages!)) + 1
    }
    
    var userSettings: UserSettings? {
        didSet {
            guard let userSettings = userSettings else { return }
            updateActivityIndicator(for: userSettings)
        }
    }
    
    /// Whether the continuous scrolling mode is enabled.
    var isScrollEnabled: Bool {
        let userEnabled = (userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable)?.on ?? false
        // Force-enables scroll when VoiceOver is running.
        return userEnabled || UIAccessibility.isVoiceOverRunning
    }

    var documentLoaded = false

    var hasLoadedJsEvents = false
    
    var jsEvents: [String: (Any) -> Void] {
        return [
            "tap": didTap,
            "didLoad": documentDidLoad,
            "updateProgression": progressionDidChange
        ]
    }
    
    var sizeObservation: NSKeyValueObservation?
    
    private static var gesturesScript: String? = {
        guard let url = Bundle(for: DocumentWebView.self).url(forResource: "gestures", withExtension: "js") else {
            return nil
        }
        return try? String(contentsOf: url)
    }();

    required init(baseURL: URL, initialLocation: BinaryLocation, readingProgression: ReadingProgression, animatedLoad: Bool = false, editingActions: EditingActionsController, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]) {
        self.baseURL = baseURL
        self.initialLocation = initialLocation
        self.readingProgression = readingProgression
        self.animatedLoad = animatedLoad
        self.webView = WebView(editingActions: editingActions)
        self.contentInset = contentInset
      
        super.init(frame: .zero)
        
        webView.frame = bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(webView)

        isOpaque = false
        backgroundColor = .clear
        
        setupWebView()

        sizeObservation = scrollView.observe(\.contentSize, options: .new) { [weak self] scrollView, value in
            guard let self = self, self.documentLoaded else {
                return
            }
            
            let scrollMode = self.isScrollEnabled
            let contentSize = value.newValue ?? .zero
            let pageSize = scrollView.frame.size
            let documentLength = scrollMode ? contentSize.height : contentSize.width
            let pageLength = scrollMode ? pageSize.height : pageSize.width
            guard documentLength > 0, pageLength > 0 else {
                return
            }
            let pageCount = Int(documentLength / pageLength)
            if self.totalPages != pageCount {
                self.totalPages = pageCount
                self.viewDelegate?.documentPageDidChange(webView: self, currentPage: self.currentPage(), totalPage: pageCount)
            }
        }
        scrollView.alpha = 0
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBackground)))
        
        if let gesturesScript = DocumentWebView.gesturesScript {
            webView.configuration.userContentController.addUserScript(
                WKUserScript(source: gesturesScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            )
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusDidChange), name: Notification.Name(UIAccessibilityVoiceOverStatusChanged), object: nil)
    }
    
    deinit {
        sizeObservation = nil  // needs to be deallocated before the scrollView
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupWebView() {
        webView.backgroundColor = UIColor.clear
        scrollView.backgroundColor = UIColor.clear
        
        webView.allowsBackForwardNavigationGestures = false

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        
        if #available(iOS 11.0, *) {
            // Prevents the pages from jumping down when the status bar is toggled
            scrollView.contentInsetAdjustmentBehavior = .never
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self
        scrollView.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  
    var scrollView: UIScrollView {
        return webView.scrollView
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

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }
    
    /// Evaluates the given JavaScript into the resource's HTML page.
    /// Don't use directly webView.evaluateJavaScript as the resource might be displayed into an iframe in a wrapper HTML page.
    func evaluateScriptInResource(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }
  
    /// Called from the JS code when a tap is detected.
    private func didTap(body: Any) {
        guard let body = body as? [String: Any],
            let point = pointFromTap(body) else
        {
            return
        }

        viewDelegate?.webView(self, didTapAt: point)
    }
    
    /// Converts the touch data returned by the JavaScript `tap` event into a point in the webview's coordinate space.
    func pointFromTap(_ data: [String: Any]) -> CGPoint? {
        // To override in subclasses.
        return nil
    }
    
    /// Called by the UITapGestureRecognizer as a fallback tap when tapping around the webview.
    @objc private func didTapBackground(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        viewDelegate?.webView(self, didTapAt: point)
    }

    /// Called by the javascript code to notify on DocumentReady.
    ///
    /// - Parameter body: Unused.
    private func documentDidLoad(body: Any) {
        documentLoaded = true

        applyUserSettingsStyle()

        // FIXME: We need to give the CSS and webview time to layout correctly. 0.2 seconds seems like a good value for it to work on an iPhone 5s. Look into solving this better
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.scrollToInitialPosition {
                self.activityIndicatorView?.stopAnimating()
                UIView.animate(withDuration: self.animatedLoad ? 0.3 : 0, animations: {
                    self.scrollView.alpha = 1
                })
            }
        }
    }

    // Scroll at position 0-1 (0%-100%)
    func scrollAt(position: Double, completion: @escaping () -> Void = {}) {
        guard position >= 0 && position <= 1 else {
            log(.warning, "Scrolling to invalid position \(position)")
            completion()
            return
        }

        // Note: The JS layer does not take into account the scroll view's content inset. So it can't be used to reliably scroll to the top or the bottom of the page in scroll mode.
        if isScrollEnabled && [0, 1].contains(position) {
            var contentOffset = scrollView.contentOffset
            contentOffset.y = (position == 0)
                ? -scrollView.contentInset.top
                : (scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
            scrollView.contentOffset = contentOffset
            completion()
        } else {
            let dir = readingProgression.rawValue
            evaluateScriptInResource("readium.scrollToPosition(\'\(position)\', \'\(dir)\')") { _, _ in completion () }
        }
    }

    // Scroll at the tag with id `tagId`.
    func scrollAt(tagId: String, completion: @escaping () -> Void = {}) {
        evaluateScriptInResource("readium.scrollToId(\'\(tagId)\');") { _, _ in completion() }
    }

    // Scroll to .beggining or .end.
    func scrollAt(location: BinaryLocation, completion: @escaping () -> Void = {}) {
        switch location {
        case .left:
            scrollAt(position: 0, completion: completion)
        case .right:
            scrollAt(position: 1, completion: completion)
        }
    }

    /// Moves the webView to the initial location.
    func scrollToInitialPosition(completion: @escaping () -> Void = {}) {
        /// If the savedProgression property has been set by the navigator.
        if let initialPosition = progression, initialPosition > 0.0 {
            scrollAt(position: initialPosition, completion: completion)
        } else if let initialId = initialId {
            scrollAt(tagId: initialId, completion: completion)
        } else {
            scrollAt(location: initialLocation, completion: completion)
        }
    }

    enum ScrollDirection {
        case left
        case right
    }
    
    func scrollTo(_ direction: ScrollDirection, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        if isScrollEnabled {
            guard let viewDelegate = viewDelegate else {
                return false
            }
            switch direction {
            case .left:
                return viewDelegate.displayLeftDocument(animated: animated, completion: completion)
            case .right:
                return viewDelegate.displayRightDocument(animated: animated, completion: completion)
            }
        }
        
        let viewDelegate = self.viewDelegate
        if animated {
            switch direction {
            case .left:
                let isAtFirstPageInDocument = scrollView.contentOffset.x == 0
                if !isAtFirstPageInDocument {
                    viewDelegate?.willAnimatePageChange()
                    scrollView.scrollToPreviousPage(animated: animated, completion: completion)
                    return true
                }
            case .right:
                let isAtLastPageInDocument = scrollView.contentOffset.x == scrollView.contentSize.width - scrollView.frame.size.width
                if !isAtLastPageInDocument {
                    viewDelegate?.willAnimatePageChange()
                    scrollView.scrollToNextPage(animated: animated, completion: completion)
                    return true
                }
            }
        }
        
        let dir = readingProgression.rawValue
        switch direction {
        case .left:
            evaluateScriptInResource("readium.scrollLeft(\"\(dir)\");") { result, error in
                if error == nil, let success = result as? Bool, !success {
                    viewDelegate?.displayLeftDocument(animated: animated, completion: completion)
                } else {
                    completion()
                }
            }
        case .right:
            evaluateScriptInResource("readium.scrollRight(\"\(dir)\");") { result, error in
                if error == nil, let success = result as? Bool, !success {
                    viewDelegate?.displayRightDocument(animated: animated, completion: completion)
                } else {
                    completion()
                }
            }
        }
        return true
    }

    /// Update webview style to userSettings.
    /// To override in subclasses.
    func applyUserSettingsStyle() {
        assert(Thread.isMainThread, "User settings must be updated from the main thread")
    }
    
    
    // MARK: - Progression change
    
    // To check if a progression change was cancelled or not.
    private var previousProgression: Double?

    // Called by the javascript code to notify that scrolling ended.
    private func progressionDidChange(body: Any) {
        guard documentLoaded, let bodyString = body as? String, let newProgression = Double(bodyString) else {
            return
        }
        
        if previousProgression == nil {
            previousProgression = progression
        }
        
        progression = newProgression
    }
    
    @objc private func notifyDocumentPageChange() {
        guard previousProgression != progression, let pages = totalPages else {
            return
        }
        previousProgression = nil
        viewDelegate?.documentPageDidChange(webView: self, currentPage: currentPage(), totalPage: pages)
    }
    
    
    // MARK: - Accessibility
    
    private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    
    @objc private func voiceOverStatusDidChange() {
        // Avoids excessive settings refresh when the status didn't change.
        guard isVoiceOverRunning != UIAccessibility.isVoiceOverRunning else {
            return
        }
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        // Scroll mode will be activated if VoiceOver is on
        applyUserSettingsStyle()
    }

}

// MARK: - WKScriptMessageHandler for handling incoming message from the Bridge.js
// javascript code.
extension DocumentWebView: WKScriptMessageHandler {

    // Handles incoming calls from JS.
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if let handler = jsEvents[message.name] {
            handler(message.body)
        }
    }

    /// Add a message handler for incoming javascript events.
    func addMessageHandlers() {
        if hasLoadedJsEvents { return }
        // Add the message handlers.
        for eventName in jsEvents.keys {
            webView.configuration.userContentController.add(self, name: eventName)
        }
        hasLoadedJsEvents = true
    }

    // Deinit message handlers (preventing strong reference cycle).
    func removeMessageHandlers() {
        for eventName in jsEvents.keys {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: eventName)
        }
        hasLoadedJsEvents = false
    }
}

extension DocumentWebView: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Do not remove: overriden in subclasses.
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var policy: WKNavigationActionPolicy = .allow

        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                // Check if url is internal or external
                if url.host == baseURL.host {
                    let href = url.absoluteString.replacingOccurrences(of: baseURL.absoluteString, with: "/")
                    viewDelegate?.handleTapOnInternalLink(with: href)
                } else {
                    viewDelegate?.handleTapOnLink(with: url)
                }
                
                policy = .cancel
            }
        }

        decisionHandler(policy)
    }
}

extension DocumentWebView: UIScrollViewDelegate {

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollView.isUserInteractionEnabled = true
        viewDelegate?.didEndPageAnimation()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        webView.dismissUserSelection()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        viewDelegate?.didEndPageAnimation()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewDelegate?.didEndPageAnimation()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Makes sure we always receive the "ending scroll" event.
        // ie. https://stackoverflow.com/a/1857162/1474476
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(notifyDocumentPageChange), object: nil)
        perform(#selector(notifyDocumentPageChange), with: nil, afterDelay: 0.3)
    }

}

extension DocumentWebView: WKUIDelegate {
    
    // The property allowsLinkPreview is default false in iOS9, so it should be safe to use @available(iOS 10.0, *)
    @available(iOS 10.0, *)
    func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        // Preview allowed only if the link is not internal
        return (elementInfo.linkURL?.host != baseURL.host)
    }
}

private extension UIScrollView {
    
    func scrollToNextPage(animated: Bool, completion: () -> Void) {
        moveHorizontalContent(with: bounds.size.width, animated: animated, completion: completion)
    }
    
    func scrollToPreviousPage(animated: Bool, completion: () -> Void) {
        moveHorizontalContent(with: -bounds.size.width, animated: animated, completion: completion)
    }
    
    private func moveHorizontalContent(with offsetX: CGFloat, animated: Bool, completion: () -> Void) {
        isUserInteractionEnabled = false
        
        var newOffset = contentOffset
        newOffset.x += offsetX
        let rounded = round(newOffset.x / offsetX) * offsetX
        newOffset.x = rounded
        let area = CGRect.init(origin: newOffset, size: bounds.size)
        scrollRectToVisible(area, animated: animated)
        // FIXME: completion needs to be implemented using scroll view delegate
        completion()
    }
}

private extension DocumentWebView {

    func updateActivityIndicator(for userSettings: UserSettings) {
        guard let appearance = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) as? Enumerable else { return }
        guard appearance.values.count > appearance.index else { return }
        let value = appearance.values[appearance.index]
        switch value {
        case "readium-night-on":
            createActivityIndicator(style: .white)
        default:
            createActivityIndicator(style: .gray)
        }
    }
    
    func createActivityIndicator(style: UIActivityIndicatorView.Style) {
        guard activityIndicatorView?.style != style else {
            return
        }
        
        activityIndicatorView?.removeFromSuperview()
        let view = UIActivityIndicatorView(style: style)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)
        view.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        view.startAnimating()
        activityIndicatorView = view
    }

}
