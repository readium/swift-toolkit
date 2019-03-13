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
    func willAnimatePageChange()
    func didEndPageAnimation()
    func displayRightDocument()
    func displayLeftDocument()
    func handleCenterTap()
    func publicationIdentifier() -> String?
    func publicationBaseUrl() -> URL?
    func handleTapOnLink(with url: URL)
    func handleTapOnInternalLink(with href: String)
    func documentPageDidChanged(webview: WebView, currentPage: Int ,totalPage: Int)
    
    /// Returns whether the web view is allowed to copy the text selection to the pasteboard.
    func requestCopySelection() -> Bool
    func didCopySelection()
}

final class WebView: WKWebView {

    public weak var viewDelegate: ViewDelegate?
    fileprivate let initialLocation: BinaryLocation
    
    var readingProgression: ReadingProgression?

    var pageTransition: PageTransition
    var editingActions: [EditingAction]
    
    weak var activityIndicatorView: UIActivityIndicatorView?

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
    
    internal var userSettings: UserSettings? {
        didSet {
            guard let userSettings = userSettings else { return }
            updateActivityIndicator(for: userSettings)
        }
    }

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
            switch target.pageTransition {
            case .none:
                evaluateJavascriptForScroll(on: target)
            case .animated:
                performSwipeTransition(on: target)
            }
        }
        
        private func evaluateJavascriptForScroll(on target: WebView) {
            let dir = target.readingProgression?.rawValue ?? ReadingProgression.ltr.rawValue
            
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
        
        private func performSwipeTransition(on target: WebView) {
            let scrollView = target.scrollView
            switch self {
            case .left:
                let isAtFirstPageInDocument = scrollView.contentOffset.x == 0
                if !isAtFirstPageInDocument {
                    target.viewDelegate?.willAnimatePageChange()
                    return scrollView.scrollToPreviousPage()
                }
            case .right:
                let isAtLastPageInDocument = scrollView.contentOffset.x == scrollView.contentSize.width - scrollView.frame.size.width
                if !isAtLastPageInDocument {
                    target.viewDelegate?.willAnimatePageChange()
                    return scrollView.scrollToNextPage()
                }
            }
            evaluateJavascriptForScroll(on: target)
        }
    }
    
    var sizeObservation: NSKeyValueObservation?
    
    private var shouldNotifyCopySelection = false

    init(frame: CGRect, initialLocation: BinaryLocation, pageTransition: PageTransition = .none, disableDragAndDrop: Bool = false, editingActions: [EditingAction] = []) {
        self.initialLocation = initialLocation
        self.pageTransition = pageTransition
        self.editingActions = editingActions
      
        super.init(frame: frame, configuration: .init())
        if disableDragAndDrop { disableDragAndDropInteraction() }
        isOpaque = false
        backgroundColor = UIColor.clear
        scrollView.backgroundColor = UIColor.clear
        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            // Prevents the pages from jumping down when the status bar is toggled
            scrollView.contentInsetAdjustmentBehavior = .never
        }
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
        
        scrollView.alpha = 0
        
      NotificationCenter.default.addObserver(self, selector: #selector(pasteboardDidChange), name: UIPasteboard.changedNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
  
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        for editingAction in self.editingActions {
            if action == Selector(editingAction.rawValue) {
                return true
            }
        }
        return false
    }
    
    @objc private func pasteboardDidChange() {
        if shouldNotifyCopySelection {
            shouldNotifyCopySelection = false
            viewDelegate?.didCopySelection()
        }
    }
    
    override func copy(_ sender: Any?) {
        guard viewDelegate?.requestCopySelection() ?? true else {
            return
        }
        // We rely on UIPasteboardChanged to notify the copy to the delegate because the WKWebView sets the selection in the UIPasteboard asynchronously
        shouldNotifyCopySelection = true
        super.copy(sender)
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
        
        switch pageTransition {
        case .none:
            scrollView.alpha = 1
            activityIndicatorView?.stopAnimating()
        case .animated:
            fadeInWithDelay()
        }
        
        applyUserSettingsStyle()
        scrollToInitialPosition()
    }
}

extension WebView {
    // Scroll at position 0-1 (0%-100%)
    internal func scrollAt(position: Double) {
        guard position >= 0 && position <= 1 else { return }
        
        let dir = self.readingProgression?.rawValue ?? ReadingProgression.ltr.rawValue

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
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollView.isUserInteractionEnabled = true
        viewDelegate?.didEndPageAnimation()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        viewDelegate?.didEndPageAnimation()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewDelegate?.didEndPageAnimation()
    }
}

extension WebView: WKUIDelegate {
    
    // The property allowsLinkPreview is default false in iOS9, so it should be safe to use @available(iOS 10.0, *)
    @available(iOS 10.0, *)
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
        isUserInteractionEnabled = false
        
        var newOffset = contentOffset
        newOffset.x += offsetX
        let rounded = round(newOffset.x / offsetX) * offsetX
        newOffset.x = rounded
        let area = CGRect.init(origin: newOffset, size: bounds.size)
        scrollRectToVisible(area, animated: true)
    }
}

private extension WebView {
    
    func fadeInWithDelay() {
        //TODO: We need to give the CSS and webview time to layout correctly. 0.2 seconds seems like a good value for it to work on an iPhone 5s. Look into solving this better
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.activityIndicatorView?.stopAnimating()
            UIView.animate(withDuration: 0.3, animations: {
                self.scrollView.alpha = 1
            })
        }
    }
    
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
        if pageTransition == .none { return }
        if documentLoaded { return }
      if activityIndicatorView?.style == style { return }
        activityIndicatorView?.removeFromSuperview()
      let view = UIActivityIndicatorView(style: style)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)
        view.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        view.startAnimating()
        activityIndicatorView = view
    }
    
    func disableDragAndDropInteraction() {
        if #available(iOS 11.0, *) {
            guard let webScrollView = subviews.compactMap( { $0 as? UIScrollView }).first,
                let contentView = webScrollView.subviews.first(where: { $0.interactions.count > 1 }),
                let dragInteraction = contentView.interactions.compactMap({ $0 as? UIDragInteraction }).first else { return }
            contentView.removeInteraction(dragInteraction)
        }
    }
}
