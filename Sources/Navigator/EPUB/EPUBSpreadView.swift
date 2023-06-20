//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Shared
import SwiftSoup
import WebKit

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

    /// Called when the user pressed a key down and it was not handled by the resource.
    func spreadView(_ spreadView: EPUBSpreadView, didPressKey event: KeyEvent)

    /// Called when the user released a key and it was not handled by the resource.
    func spreadView(_ spreadView: EPUBSpreadView, didReleaseKey event: KeyEvent)

    /// Called when WKWebview terminates
    func spreadViewDidTerminate()
}

class EPUBSpreadView: UIView, Loggable, PageView {
    weak var delegate: EPUBSpreadViewDelegate?
    let viewModel: EPUBNavigatorViewModel
    let spread: EPUBSpread
    private(set) var focusedResource: Link?

    let webView: WebView

    private var lastClick: ClickEvent? = nil

    /// If YES, the content will be faded in once loaded.
    let animatedLoad: Bool

    weak var activityIndicatorView: UIActivityIndicatorView?

    private(set) var spreadLoaded = false

    required init(
        viewModel: EPUBNavigatorViewModel,
        spread: EPUBSpread,
        scripts: [WKUserScript],
        animatedLoad: Bool
    ) {
        self.viewModel = viewModel
        self.spread = spread
        self.animatedLoad = animatedLoad
        webView = WebView(editingActions: viewModel.editingActions)

        super.init(frame: .zero)

        isOpaque = false
        backgroundColor = .clear

        webView.frame = bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(webView)
        setupWebView()

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapBackground))
        gestureRecognizer.delegate = self
        addGestureRecognizer(gestureRecognizer)

        for script in scripts {
            webView.configuration.userContentController.addUserScript(script)
        }
        registerJSMessages()

        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusDidChange), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)

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

        // Prevents the pages from jumping down when the status bar is toggled
        scrollView.contentInsetAdjustmentBehavior = .never

        webView.navigationDelegate = self
        webView.uiDelegate = self
        scrollView.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var scrollView: UIScrollView {
        webView.scrollView
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
              var message = error["message"] as? String
        else {
            return
        }
        message = "JavaScript: \(message)"

        if let file = error["filename"] as? String, file != "/",
           let line = error["line"] as? Int, line != 0
        {
            log(.error, message, file: file, line: line)
        } else {
            log(.error, message)
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
        if !clickEvent.defaultPrevented, clickEvent.interactiveElement == nil {
            let point = convertPointToNavigatorSpace(clickEvent.point)
            delegate?.spreadView(self, didTapAt: point)
        }
    }

    /// Converts the given JavaScript point into a point in the webview's coordinate space.
    func convertPointToNavigatorSpace(_ point: CGPoint) -> CGPoint {
        // To override in subclasses.
        point
    }

    /// Converts the given JavaScript rect into a rect in the webview's coordinate space.
    func convertRectToNavigatorSpace(_ rect: CGRect) -> CGRect {
        // To override in subclasses.
        rect
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
        applySettings()
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
        guard let shareViewController = viewModel.editingActions.makeShareViewController(from: webView) else {
            return
        }
        delegate?.spreadView(self, present: shareViewController)
    }

    /// Update webview style to userSettings.
    /// To override in subclasses.
    func applySettings() {
        assert(Thread.isMainThread, "User settings must be updated from the main thread")
    }

    // MARK: - Location and progression.

    /// Current progression in the resource with given href.
    func progression(in href: String) -> Double {
        // To be overridden in subclasses if the resource supports a progression.
        0
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
        false
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
        registerJSMessage(named: "pressKey") { [weak self] in self?.didPressKey($0) }
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

    private func didPressKey(_ event: Any) {
        guard let dict = event as? [String: Any],
              let type = dict["type"] as? String,
              let keyEvent = KeyEvent(dict: dict)
        else {
            return
        }

        if type == "keydown" {
            delegate?.spreadView(self, didPressKey: keyEvent)
        } else if type == "keyup" {
            delegate?.spreadView(self, didReleaseKey: keyEvent)
        } else {
            fatalError("Unexpected key event type: \(type)")
        }
    }

    // MARK: - Decorator

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
        applySettings()
    }

    // MARK: - Scripts

    class func loadScript(named name: String) -> String {
        Bundle.module.url(forResource: "\(name)", withExtension: "js", subdirectory: "Assets/Static/scripts")
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
                let baseURL = viewModel.publicationBaseURL
                // Check if url is internal or external
                if url.host == baseURL.host {
                    let href = url.absoluteString.replacingOccurrences(of: baseURL.absoluteString, with: "/")
                    delegate?.spreadView(self, didTapOnInternalLink: href, clickEvent: lastClick)
                } else {
                    delegate?.spreadView(self, didTapOnExternalURL: url)
                }

                policy = .cancel
            }
        }

        decisionHandler(policy)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        delegate?.spreadViewDidTerminate()
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
        elementInfo.linkURL?.host != viewModel.publicationBaseURL.host
    }
}

extension EPUBSpreadView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Prevents the tap event from being triggered by the fallback tap
        // gesture recognizer when it is also recognized by the web view.
        true
    }
}

private extension EPUBSpreadView {
    func updateActivityIndicator() {
        switch viewModel.theme {
        case .dark:
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
        addSubview(view)
        view.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
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
        defaultPrevented = dict["defaultPrevented"] as? Bool ?? false
        point = CGPoint(x: dict["x"] as? Double ?? 0, y: dict["y"] as? Double ?? 0)
        targetElement = dict["targetElement"] as? String ?? ""
        interactiveElement = dict["interactiveElement"] as? String
    }

    init?(json: Any?) {
        guard let dict = json as? [String: Any] else {
            return nil
        }
        self.init(dict: dict)
    }
}

private extension KeyEvent {
    /// Parses the dictionary created in keyboard.js
    init?(dict: [String: Any]) {
        guard let code = dict["code"] as? String else {
            return nil
        }

        switch code {
        case "Enter":
            key = .enter
        case "Tab":
            key = .tab
        case "Space":
            key = .space

        case "ArrowDown":
            key = .arrowDown
        case "ArrowLeft":
            key = .arrowLeft
        case "ArrowRight":
            key = .arrowRight
        case "ArrowUp":
            key = .arrowUp

        case "End":
            key = .end
        case "Home":
            key = .home
        case "PageDown":
            key = .pageDown
        case "PageUp":
            key = .pageUp

        case "MetaLeft", "MetaRight":
            key = .command
        case "ControlLeft", "ControlRight":
            key = .control
        case "AltLeft", "AltRight":
            key = .option
        case "ShiftLeft", "ShiftRight":
            key = .shift

        case "Backspace":
            key = .backspace
        case "Escape":
            key = .escape

        default:
            guard let char = dict["key"] as? String else {
                return nil
            }
            key = .character(char.lowercased())
        }

        var modifiers: KeyModifiers = []
        if let holdCommand = dict["command"] as? Bool, holdCommand {
            modifiers.insert(.command)
        }
        if let holdControl = dict["control"] as? Bool, holdControl {
            modifiers.insert(.control)
        }
        if let holdOption = dict["option"] as? Bool, holdOption {
            modifiers.insert(.option)
        }
        if let holdShift = dict["shift"] as? Bool, holdShift {
            modifiers.insert(.shift)
        }
        if let modifier = KeyModifiers(key: key) {
            modifiers.remove(modifier)
        }
        self.modifiers = modifiers
    }
}
