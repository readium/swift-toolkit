//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftSoup
@preconcurrency import WebKit

protocol EPUBSpreadViewDelegate: AnyObject {
    /// Called when the spread view finished loading.
    func spreadViewDidLoad(_ spreadView: EPUBSpreadView) async

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

    /// Called when the user triggered an input pointer event.
    func spreadView(_ spreadView: EPUBSpreadView, didReceive event: PointerEvent)

    /// Called when the user triggered an input key event.
    func spreadView(_ spreadView: EPUBSpreadView, didReceive event: KeyEvent)

    /// Called when WKWebview terminates
    func spreadViewDidTerminate()
}

class EPUBSpreadView: UIView, Loggable, PageView {
    weak var delegate: EPUBSpreadViewDelegate?
    let viewModel: EPUBNavigatorViewModel
    let spread: EPUBSpread
    private(set) var focusedResource: ReadingOrder.Index?

    let webView: WebView

    private var lastClick: ClickEvent? = nil

    /// If YES, the content will be faded in once loaded.
    let animatedLoad: Bool

    weak var activityIndicatorView: UIActivityIndicatorView?
    private var activityIndicatorStopWorkItem: DispatchWorkItem?

    private(set) var isSpreadLoaded = false

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
    @discardableResult
    func evaluateScript(_ script: String, inHREF href: AnyURL? = nil) async -> Result<Any, Error> {
        await spreadLoaded()

        log(.trace, "Evaluate script: \(script)")
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { res, error in
                if let error = error {
                    self.log(.error, error)
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(res ?? ()))
                }
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
    }

    /// Called from the JS code when receiving a pointer event.
    private func didReceivePointerEvent(_ data: Any) {
        guard
            let json = data as? [String: Any],
            // FIXME: Really needed?
            let defaultPrevented = json["defaultPrevented"] as? Bool,
            !defaultPrevented,
            // Ignores events on interactive elements
            (json["interactiveElement"] as? String) == nil,
            var event = PointerEvent(json: json)
        else {
            return
        }

        event.location = convertPointToNavigatorSpace(event.location)
        delegate?.spreadView(self, didReceive: event)
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

    // We override the UIResponder touches callbacks to handle taps around the
    // web view.

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        on(.down, touches: touches, event: event)
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        on(.move, touches: touches, event: event)
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        on(.cancel, touches: touches, event: event)
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        on(.up, touches: touches, event: event)
    }

    private func on(_ phase: PointerEvent.Phase, touches: Set<UITouch>, event: UIEvent?) {
        for touch in touches {
            delegate?.spreadView(self, didReceive: PointerEvent(
                pointer: Pointer(touch: touch, event: event),
                phase: phase,
                location: touch.location(in: self),
                modifiers: KeyModifiers(event: event)
            ))
        }
    }

    private func spreadLoadDidStart(_ body: Any) {}

    /// Called by the javascript code when the spread contents is fully loaded.
    /// The JS message `spreadLoaded` needs to be emitted by a subclass script, EPUBSpreadView's scripts don't.
    private func spreadDidLoad(_ body: Any) {
        Task { @MainActor in
            isSpreadLoaded = true
            applySettings()
            await spreadDidLoad()
            await delegate?.spreadViewDidLoad(self)
            onSpreadLoadedCallbacks.complete()
            showSpread()
        }
    }

    /// To be overriden to customize the behavior after the spread is loaded.
    func spreadDidLoad() async {}

    private let onSpreadLoadedCallbacks = CompletionList()

    /// Awaits for the spread to be fully loaded.
    func spreadLoaded() async {
        if isSpreadLoaded {
            return
        }

        await withCheckedContinuation { continuation in
            whenSpreadLoaded {
                continuation.resume()
            }
        }
    }

    /// Executes the given `callback` when the spread is fully loaded.
    func whenSpreadLoaded(_ callback: @escaping () -> Void) {
        let callback = onSpreadLoadedCallbacks.add(callback)
        if isSpreadLoaded {
            callback()
        }
    }

    func showSpread() {
        activityIndicatorView?.stopAnimating()
        activityIndicatorStopWorkItem?.cancel()
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
            let hrefString = selection["href"] as? String,
            let href = AnyURL(string: hrefString),
            let text = try? Locator.Text(json: selection["text"]),
            var frame = CGRect(json: selection["rect"])
        else {
            focusedResource = nil
            delegate?.spreadView(self, selectionDidChange: nil, frame: .zero)
            log(.warning, "Invalid body for selectionDidChange: \(body)")
            return
        }

        focusedResource = viewModel.readingOrder.firstIndexWithHREF(href)
        frame.origin = convertPointToNavigatorSpace(frame.origin)
        delegate?.spreadView(self, selectionDidChange: text, frame: frame)
    }

    /// Update webview style to userSettings.
    /// To override in subclasses.
    func applySettings() {
        assert(Thread.isMainThread, "User settings must be updated from the main thread")
    }

    // MARK: - Location and progression.

    /// Current progression in the resource with given href.
    func progression(in index: ReadingOrder.Index) -> ClosedRange<Double> {
        // To be overridden in subclasses if the resource supports a progression.
        0 ... 1
    }

    func go(to location: PageLocation) async {
        fatalError("go(to:) must be implemented in subclasses")
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

    func go(to direction: Direction, options: NavigatorGoOptions) async -> Bool {
        // The default implementation of a spread view considers that its content is entirely visible on screen.
        false
    }

    func findFirstVisibleElementLocator() async -> Locator? {
        let result = await evaluateScript("readium.findFirstVisibleLocator()")
        do {
            let resource = viewModel.readingOrder[spread.leading]
            let locator = try Locator(json: result.get())?
                .copy(href: resource.url(), mediaType: resource.mediaType ?? .xhtml)
            return locator
        } catch {
            log(.error, error)
            return nil
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
        registerJSMessage(named: "pointerEventReceived") { [weak self] in self?.didReceivePointerEvent($0) }
        registerJSMessage(named: "spreadLoadStarted") { [weak self] in self?.spreadLoadDidStart($0) }
        registerJSMessage(named: "spreadLoaded") { [weak self] in self?.spreadDidLoad($0) }
        registerJSMessage(named: "selectionChanged") { [weak self] in self?.selectionDidChange($0) }
        registerJSMessage(named: "decorationActivated") { [weak self] in self?.decorationDidActivate($0) }
        registerJSMessage(named: "keyEventReceived") { [weak self] in self?.didReceiveKeyEvent($0) }
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

    private func didReceiveKeyEvent(_ event: Any) {
        guard
            let dict = event as? [String: Any],
            let keyEvent = KeyEvent(dict: dict)
        else {
            return
        }

        delegate?.spreadView(self, didReceive: keyEvent)
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
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log(.error, error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setNeedsStopActivityIndicator()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var policy: WKNavigationActionPolicy = .allow

        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url?.httpURL {
                // Check if url is internal or external
                if let relativeURL = viewModel.publicationBaseURL.relativize(url) {
                    delegate?.spreadView(self, didTapOnInternalLink: relativeURL.string, clickEvent: lastClick)
                } else {
                    delegate?.spreadView(self, didTapOnExternalURL: url.url)
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

extension EPUBSpreadView: WKUIDelegate {}

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
            createActivityIndicator(color: .white)
        default:
            createActivityIndicator(color: .systemGray)
        }
    }

    func createActivityIndicator(color: UIColor) {
        guard activityIndicatorView?.color != color else {
            return
        }

        activityIndicatorView?.removeFromSuperview()
        let view = UIActivityIndicatorView(style: .medium)
        view.color = color
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        view.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        view.startAnimating()
        activityIndicatorView = view
    }

    private func setNeedsStopActivityIndicator() {
        guard activityIndicatorStopWorkItem == nil else {
            return
        }

        activityIndicatorStopWorkItem = DispatchWorkItem { [weak self] in
            defer {
                self?.activityIndicatorStopWorkItem = nil
            }

            guard
                let self = self,
                let workItem = activityIndicatorStopWorkItem,
                !workItem.isCancelled
            else {
                return
            }

            trace("stopping activity indicator because spread \(viewModel.readingOrder[spread.leading].href) did not load")
            activityIndicatorView?.stopAnimating()
        }

        // If the spread doesn't begin loading within 2 seconds it means that we
        // likely encountered an error. In that case the work item we
        // schedule below will stop the activity indicator.
        // If the spread begins to load it will send a `spreadLoadStart` JS
        // event which will cancel the work item being scheduled here.
        trace("scheduling activity indicator stop")
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 2,
            execute: activityIndicatorStopWorkItem!
        )
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

/// Produced by gestures.js
private extension PointerEvent {
    init?(json: [String: Any]) {
        guard
            let pointerId = json["pointerId"] as? Int,
            let pointerType = json["pointerType"] as? String,
            let phase = PointerEvent.Phase(json: json["phase"]),
            let x = json["x"] as? Double,
            let y = json["y"] as? Double
        else {
            return nil
        }

        let optionalPointer: Pointer? = switch pointerType {
        case "mouse":
            .mouse(MousePointer(id: pointerId, buttons: MouseButtons(json: json)))
        case "touch":
            .touch(TouchPointer(id: pointerId))
        default:
            nil
        }

        guard let pointer = optionalPointer else {
            return nil
        }

        self.init(
            pointer: pointer,
            phase: phase,
            location: CGPoint(x: x, y: y),
            modifiers: KeyModifiers(json: json)
        )
        // FIXME:
//        targetElement = dict["targetElement"] as? String ?? ""
//        interactiveElement = dict["interactiveElement"] as? String
    }
}

private extension MouseButtons {
    init(json: [String: Any]) {
        self.init()

        guard let buttons = json["buttons"] as? Int else {
            return
        }

        self = MouseButtons(rawValue: buttons)
    }
}

private extension PointerEvent.Phase {
    init?(json: Any?) {
        guard let json = json as? String else {
            return nil
        }

        switch json {
        case "down": self = .down
        case "cancel": self = .cancel
        case "move": self = .move
        case "up": self = .up
        default: return nil
        }
    }
}

private extension KeyModifiers {
    init(json: [String: Any]) {
        self.init()

        if (json["control"] as? Bool) ?? false {
            insert(.control)
        }
        if (json["command"] as? Bool) ?? false {
            insert(.command)
        }
        if (json["shift"] as? Bool) ?? false {
            insert(.shift)
        }
        if (json["option"] as? Bool) ?? false {
            insert(.option)
        }
    }
}

private extension KeyEvent {
    /// Parses the dictionary created in keyboard.js
    init?(dict: [String: Any]) {
        guard
            let phase = Phase(json: dict["phase"]),
            let code = dict["code"] as? String
        else {
            return nil
        }

        let key: Key
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

        var modifiers = KeyModifiers(json: dict)
        if let modifier = KeyModifiers(key: key) {
            modifiers.remove(modifier)
        }

        self.init(phase: phase, key: key, modifiers: modifiers)
    }
}

private extension KeyEvent.Phase {
    init?(json: Any?) {
        guard let json = json as? String else {
            return nil
        }

        switch json {
        case "up": self = .up
        case "down": self = .down
        default: return nil
        }
    }
}
