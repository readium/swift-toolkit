//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import WebKit

/// A pool of web views shared by the EPUB navigators of an application.
///
/// Creating a `WKWebView` spawns a web content process, and the first
/// navigation on a custom URL scheme costs seconds more, once per web view.
/// Together they dominate the time it takes to display the first spread of a
/// publication.
///
/// Hold a pool for the lifetime of the application, ``prewarm(count:)`` it
/// while the reader is still browsing, and pass it to
/// ``EPUBNavigatorViewController/Configuration/webViewPool``. Web views
/// outlive the navigators using them and are handed back when a navigator goes
/// away, so opening a second publication reuses the first one's web views.
///
/// The pool is safe to share across publications: every web view is stripped
/// of the previous navigator's scripts, message handlers and editing rights
/// before being handed out.
@MainActor
public final class EPUBWebViewPool {
    /// Maximum number of web views kept alive.
    public let capacity: Int

    private var available: [WebView] = []

    /// How many web views the pool has been asked to keep ready.
    private var prewarmTarget = 0

    /// Web views handed out and not given back yet.
    ///
    /// While any is outstanding a reader is on screen, and the pool stays out
    /// of its way.
    private var borrowedCount = 0

    /// Web views being warmed up right now, kept so the work can be abandoned
    /// when a reader needs the device.
    private var warmingUp: [WebView] = []

    /// Whether the warm-up in progress was interrupted by a reader.
    private var didAbortWarmup = false

    /// Creates a pool holding at most `capacity` web views.
    ///
    /// The default covers the first spread and its immediate neighbours, which
    /// is what the reader waits on. A navigator's full pre-load window is
    /// larger, so the spreads beyond those fall back to building web views
    /// from scratch — off the critical path, while the reader is already
    /// reading. Worth revisiting once the trade-off has been measured.
    public init(capacity: Int = 4) {
        precondition(capacity >= 0)
        self.capacity = capacity
    }

    /// Number of web views ready to be handed out.
    public var count: Int { available.count }

    /// Creates web views ahead of time and pays their one-off costs, so that
    /// opening a publication does not have to.
    ///
    /// Call this once the application's window is up and the reader is doing
    /// something else. Each web view spawns its web content process and
    /// performs a real navigation on the Readium URL scheme, which is what
    /// discharges the expensive first navigation. The warm-ups run together
    /// rather than one after another.
    ///
    /// ### Yielding to the reader
    ///
    /// Warming up competes with a publication being opened, to the point of
    /// making the open slower than having no pool at all. The pool therefore
    /// never works while a reader does:
    ///
    /// - a checkout abandons whatever is still warming up, and web views whose
    ///   navigation was cut short are discarded rather than pooled, since they
    ///   may not have paid the first-navigation cost;
    /// - nothing is built again while web views are still out on loan. A
    ///   reading session needs no new stock: the web views come back when the
    ///   navigator goes away, which restocks the pool for free;
    /// - returning the last borrowed web view tops the pool back up if it
    ///   ended up below the target.
    ///
    /// A pool emptied by a reader that borrowed nothing back stays empty, as
    /// there is no return to trigger a refill. Call this method again to
    /// restock; it is safe at any point and does nothing while a reader holds
    /// web views.
    public func prewarm(count: Int) async {
        prewarmTarget = min(max(prewarmTarget, count), capacity)
        await refill()
    }

    /// Brings the pool up to its prewarm target, unless a reader is using it.
    private func refill() async {
        guard borrowedCount == 0, warmingUp.isEmpty else {
            return
        }

        let missing = min(prewarmTarget, capacity) - available.count
        guard missing > 0 else {
            return
        }

        didAbortWarmup = false
        warmingUp = (0 ..< missing).map { _ in Self.makeWebView() }

        // The navigations are independent, so they run together. WebKit may
        // still serialize process spawns internally, but that is its call to
        // make, not ours.
        await withTaskGroup(of: WebView?.self) { group in
            for webView in warmingUp {
                group.addTask { @MainActor in
                    await Self.warmUp(webView)
                    // A navigation that was stopped part-way may not have paid
                    // the first-navigation cost. Pooling such a web view would
                    // hand that cost to the reader later, unpredictably.
                    return self.didAbortWarmup ? nil : webView
                }
            }

            for await webView in group {
                if let webView, available.count < capacity {
                    available.append(webView)
                }
            }
        }

        warmingUp = []
    }

    /// Abandons any warm-up in flight so it stops competing with a reader.
    ///
    /// Stopping the navigation is what actually frees the device: cancelling
    /// the task alone would not, since a warm-up sits waiting on its
    /// navigation delegate.
    private func abortWarmup() {
        guard !warmingUp.isEmpty else {
            return
        }

        didAbortWarmup = true
        for webView in warmingUp {
            webView.stopLoading()
        }
    }

    // MARK: - Checkout

    /// Hands out a web view bound to the given publication's editing rights,
    /// or `nil` if the pool is empty.
    ///
    /// This is the only way to obtain a web view from the pool, so that one
    /// cannot reach a navigator while still carrying the previous
    /// publication's scripts, message handlers or rights.
    func checkout(editingActions: EditingActionsController) -> WebView? {
        // A reader is opening a publication, whether or not the pool can serve
        // it. Warming up alongside would slow that open down more than the
        // pool speeds it up.
        abortWarmup()

        guard !available.isEmpty else {
            return nil
        }

        borrowedCount += 1
        let webView = available.removeLast()

        // Stripped again on the way out, even though `giveBack` already did:
        // the cost is negligible and it keeps the guarantee local to the one
        // function that hands web views to navigators.
        strip(webView)
        webView.rebind(editingActions: editingActions)
        return webView
    }

    /// Takes a web view back once its navigator is gone.
    ///
    /// The web view is stripped right away rather than on its way out again:
    /// an idling pooled web view must not keep the previous publication's
    /// scripts installed, nor keep its editing rights controller — and through
    /// it the publication's `UserRights` — alive.
    ///
    /// Ignored when the pool is already full, letting the web view be
    /// released.
    func giveBack(_ webView: WebView) {
        borrowedCount = max(0, borrowedCount - 1)

        guard available.count < capacity else {
            return
        }

        strip(webView)
        available.append(webView)

        // The reading session is over. Returns usually restock the pool on
        // their own; build the difference only if they did not.
        if borrowedCount == 0, available.count < prewarmTarget {
            Task { await refill() }
        }
    }

    /// Removes everything a navigator installed on a web view, leaving it
    /// bound to no publication.
    private func strip(_ webView: WebView) {
        webView.stopLoading()
        webView.removeFromSuperview()

        // Scripts and handlers are installed per navigator, in
        // `EPUBSpreadView.init` and through the `setupUserScripts` delegate.
        // Removing them does not re-arm the first-navigation cost.
        let contentController = webView.configuration.userContentController
        contentController.removeAllUserScripts()
        contentController.removeAllScriptMessageHandlers()

        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.scrollView.delegate = nil

        webView.unbindFromPublication()
    }

    // MARK: - Web view creation

    /// Builds a web view bound to the shared server.
    ///
    /// The URL scheme handler is registered on the configuration before the
    /// web view is created, because it cannot be changed afterwards. This is
    /// why pooled web views only work with navigators served by
    /// ``WebViewServer/shared``.
    static func makeWebView() -> WebView {
        let server = WebViewServer.shared

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(server, forURLScheme: server.scheme)
        config.mediaTypesRequiringUserActionForPlayback = .all

        // Publication documents have no use for persistent storage, and their
        // origin embeds a per-navigator identifier: anything written would be
        // unreachable on the next open and would only accumulate on disk.
        config.websiteDataStore = .nonPersistent()

        // Disable the Apple Intelligence Writing tools in the web views.
        // See https://github.com/readium/swift-toolkit/issues/509#issuecomment-2577780749
        if #available(iOS 18.0, *) {
            config.writingToolsBehavior = .none
        }

        // No publication is bound yet: the web view denies every editing
        // action until `checkout(editingActions:)` rebinds it.
        return WebView(configuration: config)
    }

    /// Performs the first navigation on the Readium scheme, which every web
    /// view pays once.
    private static func warmUp(_ webView: WebView) async {
        let delegate = WarmupNavigationDelegate()
        webView.navigationDelegate = delegate
        defer { webView.navigationDelegate = nil }

        webView.load(URLRequest(url: WebViewServer.shared.warmupURL.url))
        await delegate.wait()
    }
}

/// Awaits the end of the warm-up navigation.
private final class WarmupNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isDone = false

    func wait() async {
        guard !isDone else {
            return
        }

        await withCheckedContinuation { continuation = $0 }
    }

    private func finish() {
        isDone = true
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        finish()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        finish()
    }
}
