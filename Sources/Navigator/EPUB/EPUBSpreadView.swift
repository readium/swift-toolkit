//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import WebKit
import R2Shared
import SwiftSoup

protocol EPUBSpreadViewDelegate: AnyObject {
    /// Called when the spread view finished loading.
    func spreadViewDidLoad(_ spreadView: EPUBSpreadView)

    /// Called when the user tapped on the spread contents.
    func spreadView(_ spreadView: EPUBSpreadView, didTapAt point: CGPoint)
    
    /// Called when the user tapped on an external link.
    func spreadView(_ spreadView: EPUBSpreadView, didTapOnExternalURL url: URL)
    
    /// Called when the user tapped on an internal link.
    func spreadView(_ spreadView: EPUBSpreadView, didTapOnInternalLink href: String, clickEvent: ClickEvent?)

    /// Called when the user tapped on a decoration.
    func spreadView(_ spreadView: EPUBSpreadView, didActivateDecoration id: Decoration.Id, inGroup group: String, frame: CGRect?, point: CGPoint?)

    /// Called when the text selection changes.
    func spreadView(_ spreadView: EPUBSpreadView, selectionDidChange text: Locator.Text?, frame: CGRect)

    /// Called when the pages visible in the spread changed.
    func spreadViewPagesDidChange(_ spreadView: EPUBSpreadView)
    
    /// Called when the spread view needs to present a view controller.
    func spreadView(_ spreadView: EPUBSpreadView, present viewController: UIViewController)
}

class EPUBSpreadView: UIView, Loggable, PageView {

    weak var delegate: EPUBSpreadViewDelegate?
    let publication: Publication
    let spread: EPUBSpread
    private(set) var focusedResource: Link?
    
    let resourcesURL: URL
    let webView: WebView

    let readingProgression: ReadingProgression
    let userSettings: UserSettings
    let editingActions: EditingActionsController

    private var lastClick: ClickEvent? = nil

    /// If YES, the content will be faded in once loaded.
    let animatedLoad: Bool
    
    let contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]

    weak var activityIndicatorView: UIActivityIndicatorView?

    /// Whether the continuous scrolling mode is enabled.
    var isScrollEnabled: Bool {
        let userEnabled = (userSettings.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable)?.on ?? false
        // Force-enables scroll when VoiceOver is running.
        return userEnabled || UIAccessibility.isVoiceOverRunning
    }

    private(set) var spreadLoaded = false

    required init(publication: Publication, spread: EPUBSpread, resourcesURL: URL, readingProgression: ReadingProgression, userSettings: UserSettings, scripts: [WKUserScript], animatedLoad: Bool = false, editingActions: EditingActionsController, contentInset: [UIUserInterfaceSizeClass: EPUBContentInsets]) {
        self.publication = publication
        self.spread = spread
        self.resourcesURL = resourcesURL
        self.readingProgression = readingProgression
        self.userSettings = userSettings
        self.editingActions = editingActions
        self.animatedLoad = animatedLoad
        self.webView = WebView(editingActions: editingActions)
        self.contentInset = contentInset

        super.init(frame: .zero)
        
        isOpaque = false
        backgroundColor = .clear
        
        webView.frame = bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(webView)
        setupWebView()

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBackground)))
        
        for script in scripts {
            webView.configuration.userContentController.addUserScript(script)
        }
        registerJSMessages()

        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusDidChange), name: Notification.Name(UIAccessibilityVoiceOverStatusChanged), object: nil)

        updateActivityIndicator()
        loadSpread()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        disableJSMessages()
    }

    func setupWebView() {
        scrollView.alpha = 0
        
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
        super.didMoveToSuperview()
        
        if superview == nil {
            disableJSMessages()
            // Fixing an iOS 9 bug by explicitly clearing scrollView.delegate before deinitialization
            scrollView.delegate = nil
        } else {
            enableJSMessages()
            scrollView.delegate = self
        }
    }
    
    func loadSpread() {
        fatalError("loadSpread() must be implemented in subclasses")
    }

    /// Evaluates the given JavaScript into the resource's HTML page.
    func evaluateScript(_ script: String, inHREF href: String? = nil, completion: ((Result<Any, Error>) -> Void)? = nil) {
        log(.debug, "Evaluate script: \(script)")
        webView.evaluateJavaScript(script) { res, error in
            if let error = error {
                self.log(.error, error)
                completion?(.failure(error))
            } else {
                completion?(.success(res ?? ()))
            }
        }
    }

    /// Called from the JS code when logging a message.
    private func didLog(_ body: Any) {
        guard let body = body as? String else {
            return
        }
        log(.debug, "JavaScript: \(body)")
    }

    /// Called from the JS code when logging an error.
    private func didLogError(_ body: Any) {
        guard let error = body as? [String: Any],
            var message = error["message"] as? String else
        {
            return
        }
        message = "JavaScript: \(message)"

        if let file = error["filename"] as? String, file != "/",
            let line = error["line"] as? Int, line != 0
        {
            self.log(.error, message, file: file, line: line)
        } else {
            self.log(.error, message)
        }
    }

    /// Called from the JS code when a tap is detected.
    /// If the JS indicates the tap is being handled within the webview, don't take action,
    /// just save the tap data for use by webView(_ webView:decidePolicyFor:decisionHandler:)
    private func didTap(_ data: Any) {
        guard let clickEvent = ClickEvent(json: data) else {
            return
        }
        lastClick = clickEvent
        
        // Ignores taps on interactive elements, or if the script prevents the default behavior.
        if !clickEvent.defaultPrevented && clickEvent.interactiveElement == nil {
            let point = convertPointToNavigatorSpace(clickEvent.point)
            delegate?.spreadView(self, didTapAt: point)
        }
    }

    /// Converts the given JavaScript point into a point in the webview's coordinate space.
    func convertPointToNavigatorSpace(_ point: CGPoint) -> CGPoint {
        // To override in subclasses.
        return point
    }

    /// Converts the given JavaScript rect into a rect in the webview's coordinate space.
    func convertRectToNavigatorSpace(_ rect: CGRect) -> CGRect {
        // To override in subclasses.
        return rect
    }

    /// Called by the UITapGestureRecognizer as a fallback tap when tapping around the webview.
    @objc private func didTapBackground(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        delegate?.spreadView(self, didTapAt: point)
    }

    /// Called by the javascript code when the spread contents is fully loaded.
    /// The JS message `spreadLoaded` needs to be emitted by a subclass script, EPUBSpreadView's scripts don't.
    private func spreadDidLoad(_ body: Any) {
        spreadLoaded = true
        applyUserSettingsStyle()
        spreadDidLoad()
        delegate?.spreadViewDidLoad(self)
    }
    
    /// To be overriden to customize the behavior after the spread is loaded.
    func spreadDidLoad() {
        showSpread()
    }
    
    func showSpread() {
        activityIndicatorView?.stopAnimating()
        UIView.animate(withDuration: animatedLoad ? 0.3 : 0, animations: {
            self.scrollView.alpha = 1
        })
    }

    /// Called by the JavaScript layer when the user selection changed.
    private func selectionDidChange(_ body: Any) {
        if body is NSNull {
            focusedResource = nil
            delegate?.spreadView(self, selectionDidChange: nil, frame: .zero)
            return
        }

        guard
            let selection = body as? [String: Any],
            let href = selection["href"] as? String,
            let text = try? Locator.Text(json: selection["text"]),
            var frame = CGRect(json: selection["rect"])
        else {
            focusedResource = nil
            delegate?.spreadView(self, selectionDidChange: nil, frame: .zero)
            log(.warning, "Invalid body for selectionDidChange: \(body)")
            return
        }

        focusedResource = spread.links.first(withHREF: href)
        frame.origin = convertPointToNavigatorSpace(frame.origin)
        delegate?.spreadView(self, selectionDidChange: text, frame: frame)
    }
    
    /// Called when the user hit the Share item in the selection context menu.
    @objc func shareSelection(_ sender: Any?) {
        guard let shareViewController = editingActions.makeShareViewController(from: webView) else {
            return
        }
        delegate?.spreadView(self, present: shareViewController)
    }

    /// Update webview style to userSettings.
    /// To override in subclasses.
    func applyUserSettingsStyle() {
        assert(Thread.isMainThread, "User settings must be updated from the main thread")
    }
    
    
    /// MARK: - Location and progression.
    
    /// Current progression in the resource with given href.
    func progression(in href: String) -> Double {
        // To be overridden in subclasses if the resource supports a progression.
        return 0
    }

    func go(to location: PageLocation, completion: (() -> Void)?) {
        fatalError("go(to:completion:) must be implemented in subclasses")
    }
    
    enum Direction: CustomStringConvertible {
        case left
        case right
        
        var description: String {
            switch self {
            case .left: return "left"
            case .right: return "right"
            }
        }
    }
    
    func go(to direction: Direction, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        // The default implementation of a spread view considers that its content is entirely visible on screen.
        return false
    }

    func findFirstVisibleElementLocator(completion: @escaping (Locator?) -> Void) {
        evaluateScript("readium.findFirstVisibleLocator()") { result in
            DispatchQueue.main.async {
                do {
                    let resource = self.spread.leading
                    let locator = try Locator(json: result.get())?
                        .copy(href: resource.href, type: resource.type ?? MediaType.xhtml.string)
                    completion(locator)
                } catch {
                    self.log(.error, error)
                    completion(nil)
                }
            }
        }
    }


    // MARK: - JS Messages
    
    private var JSMessages: [String: (Any) -> Void] = [:]
    private var JSMessagesEnabled = false

    /// Register a new JS message handler to be emitted from scripts.
    func registerJSMessage(named name: String, handler: @escaping (Any) -> Void) {
        guard JSMessages[name] == nil else {
            log(.error, "JS message already registered: \(name)")
            return
        }
        
        JSMessages[name] = handler
        if JSMessagesEnabled {
            webView.configuration.userContentController.add(self, name: name)
        }
    }
    
    /// To override in subclasses if needed.
    func registerJSMessages() {
        registerJSMessage(named: "log") { [weak self] in self?.didLog($0) }
        registerJSMessage(named: "logError") { [weak self] in self?.didLogError($0) }
        registerJSMessage(named: "tap") { [weak self] in self?.didTap($0) }
        registerJSMessage(named: "spreadLoaded") { [weak self] in self?.spreadDidLoad($0) }
        registerJSMessage(named: "selectionChanged") { [weak self] in self?.selectionDidChange($0) }
        registerJSMessage(named: "decorationActivated") { [weak self] in self?.decorationDidActivate($0) }
    }
    
    /// Add the message handlers for incoming javascript events.
    private func enableJSMessages() {
        guard !JSMessagesEnabled else {
            return
        }
        JSMessagesEnabled = true
        for name in JSMessages.keys {
            webView.configuration.userContentController.add(self, name: name)
        }
    }
    
    // Removes message handlers (preventing strong reference cycle).
    private func disableJSMessages() {
        guard JSMessagesEnabled else {
            return
        }
        JSMessagesEnabled = false
        for name in JSMessages.keys {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
    }


    // MARK: – Decorator

    /// Called by the JavaScript layer when the user activates a decoration.
    private func decorationDidActivate(_ body: Any) {
        guard
            let decoration = body as? [String: Any],
            let decorationId = decoration["id"] as? Decoration.Id,
            let groupName = decoration["group"] as? String,
            var frame = CGRect(json: decoration["rect"])
        else {
            log(.warning, "Invalid body for decorationDidActivate: \(body)")
            return
        }

        frame = convertRectToNavigatorSpace(frame)
        let point = ClickEvent(json: decoration["click"])
            .map { convertPointToNavigatorSpace($0.point) }
        delegate?.spreadView(self, didActivateDecoration: decorationId, inGroup: groupName, frame: frame, point: point)
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

    
    // MARK: - Scripts
    
    class func loadScript(named name: String) -> String {
        return Bundle.module.url(forResource: "\(name)", withExtension: "js", subdirectory: "Assets/Static/scripts")
            .flatMap { try? String(contentsOf: $0) }!
    }
}

// MARK: - WKScriptMessageHandler for handling incoming message from the javascript layer.
extension EPUBSpreadView: WKScriptMessageHandler {

    /// Handles incoming calls from JS.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let handler = JSMessages[message.name] else {
            return
        }
        handler(message.body)
    }

}

extension EPUBSpreadView: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Do not remove: overridden in subclasses.
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var policy: WKNavigationActionPolicy = .allow

        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                // Check if url is internal or external
                if let baseURL = publication.baseURL, url.host == baseURL.host {
                    let href = url.absoluteString.replacingOccurrences(of: baseURL.absoluteString, with: "/")
                    delegate?.spreadView(self, didTapOnInternalLink: href, clickEvent: self.lastClick)
                } else {
                    delegate?.spreadView(self, didTapOnExternalURL: url)
                }
                
                policy = .cancel
            }
        }

        decisionHandler(policy)
    }
}

extension EPUBSpreadView: UIScrollViewDelegate {
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollView.isUserInteractionEnabled = true
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        webView.clearSelection()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Do not remove, overridden in subclasses.
    }

}

extension EPUBSpreadView: WKUIDelegate {
    
    func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        // Preview allowed only if the link is not internal
        return (elementInfo.linkURL?.host != publication.baseURL?.host)
    }
}

private extension EPUBSpreadView {

    func updateActivityIndicator() {
        guard let appearance = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) as? Enumerable,
            appearance.values.count > appearance.index else
        {
            return
        }
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

/// Produced by gestures.js
struct ClickEvent {
    let defaultPrevented: Bool
    let point: CGPoint
    let targetElement: String
    let interactiveElement: String?
    
    init(dict: [String: Any]) {
        self.defaultPrevented = dict["defaultPrevented"] as? Bool ?? false
        self.point = CGPoint(x: dict["x"] as? Double ?? 0, y: dict["y"] as? Double ?? 0)
        self.targetElement = dict["targetElement"] as? String ?? ""
        self.interactiveElement = dict["interactiveElement"] as? String
    }
    
    init?(json: Any?) {
        guard let dict = json as? [String: Any] else {
            return nil
        }
        self.init(dict: dict)
    }
}
