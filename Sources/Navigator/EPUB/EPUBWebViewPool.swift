//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
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

    /// Warm-ups started and not finished yet.
    private var pendingWarmups = 0

    /// Checkouts waiting for one of those warm-ups, oldest first.
    ///
    /// Each is promised the next warm-up to finish, or `nil` if that one
    /// failed, so no caller is left hanging.
    private var waiters: [CheckoutWaiter] = []

    /// How long a single warm-up is given before the pool stops counting on
    /// it. Generous on purpose: a warm-up this slow is broken, not busy.
    static let defaultWarmupTimeout: TimeInterval = 15

    private let warmupTimeout: TimeInterval

    /// Builds a web view and pays its one-off costs, or returns `nil` if that
    /// failed.
    typealias WarmupFactory = @MainActor () async -> WebView?

    private let warmup: WarmupFactory

    /// Creates a pool holding at most `capacity` web views.
    ///
    /// The default covers the first spread and its immediate neighbours, which
    /// is what the reader waits on. A navigator's full pre-load window is
    /// larger, so the spreads beyond those fall back to building web views
    /// from scratch — off the critical path, while the reader is already
    /// reading. Worth revisiting once the trade-off has been measured.
    public convenience init(capacity: Int = 4) {
        self.init(capacity: capacity, warmup: { await Self.makeWarmedWebView() })
    }

    /// Creates a pool that builds its web views with the given factory.
    ///
    /// Exists so tests can drive warm-ups deterministically; a real warm-up
    /// finishes whenever WebKit says so, which makes the timing of a checkout
    /// racing one impossible to pin down.
    init(
        capacity: Int,
        warmupTimeout: TimeInterval = EPUBWebViewPool.defaultWarmupTimeout,
        warmup: @escaping WarmupFactory
    ) {
        precondition(capacity >= 0)
        self.capacity = capacity
        self.warmupTimeout = warmupTimeout
        self.warmup = warmup
    }

    /// Number of web views ready to be handed out.
    public var count: Int { available.count }

    /// Whether a warm-up is in flight that a checkout could wait for.
    var isWarmingUp: Bool { pendingWarmups > 0 }

    /// Whether a checkout is currently waiting for a warm-up to finish.
    var hasWaitingCheckouts: Bool { !waiters.isEmpty }

    /// Creates web views ahead of time and pays their one-off costs, so that
    /// opening a publication does not have to.
    ///
    /// Call this once the application's window is up and the reader is doing
    /// something else. Each web view spawns its web content process and
    /// performs a real navigation on the Readium URL scheme, which is what
    /// discharges the expensive first navigation. The warm-ups run together
    /// rather than one after another.
    ///
    /// ### Sharing the device with the reader
    ///
    /// A publication opened while the pool is still warming up must not have
    /// to compete with it:
    ///
    /// - a checkout that finds the pool empty but a warm-up in flight waits
    ///   for it instead of building its own. The warm-up started earlier, so
    ///   its remainder is always less than a fresh build, and waiting keeps
    ///   the two from fighting over the device. Abandoning it and starting
    ///   over — which is what this used to do — measured worse than having no
    ///   pool at all;
    /// - nothing new is built while web views are out on loan. A reading
    ///   session needs no fresh stock: the web views come back when the
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
        guard borrowedCount == 0, pendingWarmups == 0 else {
            return
        }

        let missing = min(prewarmTarget, capacity) - available.count
        guard missing > 0 else {
            return
        }

        pendingWarmups = missing

        // The navigations are independent, so they run together. WebKit may
        // still serialize process spawns internally, but that is its call to
        // make, not ours.
        await withTaskGroup(of: WebView?.self) { group in
            for _ in 0 ..< missing {
                group.addTask { @MainActor in
                    await self.boundedWarmup()
                }
            }

            // Handed over one at a time, as each finishes, so a checkout
            // waiting for one is served the moment it is ready instead of
            // when the whole batch is.
            for await webView in group {
                pendingWarmups -= 1
                deliver(webView)
            }
        }
    }

    /// Runs one warm-up, giving up on it after ``warmupTimeout``.
    ///
    /// A warm-up that never comes back would leave `pendingWarmups` above zero
    /// for the rest of the process: every later refill would decline to run
    /// and every waiter would wait forever. The web content process dying is
    /// the realistic way that happens, and it is handled directly, but this
    /// backstop means no unforeseen stall can wedge the pool either.
    ///
    /// The warm-up itself cannot be forced to return, so it is left running.
    /// Should it finish late, its web view is still perfectly good and goes
    /// back into circulation.
    private func boundedWarmup() async -> WebView? {
        await withCheckedContinuation { continuation in
            let slot = WarmupSlot(continuation)

            let timeout = Task { @MainActor in
                try? await Task.sleep(seconds: warmupTimeout)
                slot.resolve(nil)
            }

            Task { @MainActor in
                let webView = await warmup()
                timeout.cancel()

                if !slot.resolve(webView), let webView {
                    // Timed out before this landed. The web view is fine, so
                    // it is offered rather than thrown away.
                    deliver(webView)
                }
            }
        }
    }

    /// Passes a finished warm-up to whoever is waiting for one, or shelves it.
    ///
    /// `nil` means the warm-up failed; the waiter is resumed with it anyway so
    /// that it falls back to building its own rather than hanging.
    private func deliver(_ webView: WebView?) {
        while !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            if waiter.resolve(webView) {
                return
            }
            // That one was cancelled between being queued and now; try the
            // next in line.
        }

        if let webView, available.count < capacity {
            available.append(webView)
        }
    }

    /// Drops a waiter whose checkout was cancelled, releasing it with nothing.
    private func cancelWaiter(_ waiter: CheckoutWaiter) {
        waiters.removeAll { $0 === waiter }
        waiter.resolve(nil)
    }

    // MARK: - Checkout

    /// Hands out a web view bound to the given publication's editing rights.
    ///
    /// Returns one straight away when the pool has stock. When it does not but
    /// a warm-up is in flight, it waits for that warm-up rather than letting
    /// the caller build a web view alongside it: the warm-up is already part
    /// way through, so its remainder costs less than a fresh build, and the
    /// two would otherwise compete.
    ///
    /// Returns `nil` only when there is nothing to wait for, or when the
    /// warm-up it waited for failed. The caller then builds its own.
    ///
    /// This is the only way to obtain a web view from the pool, so that one
    /// cannot reach a navigator while still carrying the previous
    /// publication's scripts, message handlers or rights.
    func checkout(editingActions: EditingActionsController) async -> WebView? {
        guard let webView = await claimWebView() else {
            return nil
        }

        borrowedCount += 1

        // Stripped again on the way out, even though `giveBack` already did:
        // the cost is negligible and it keeps the guarantee local to the one
        // function that hands web views to navigators.
        strip(webView)
        webView.rebind(editingActions: editingActions)
        return webView
    }

    /// Takes a web view off the shelf, or waits for one being warmed up.
    private func claimWebView() async -> WebView? {
        if let webView = available.popLast() {
            return webView
        }

        // Only wait when a warm-up is in flight that nobody ahead in the queue
        // has already been promised — otherwise this would wait for something
        // that is never coming.
        guard pendingWarmups > waiters.count else {
            return nil
        }

        let waiter = CheckoutWaiter()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiter.attach(continuation)
                waiters.append(waiter)
            }
        } onCancel: {
            // A cancelled load chain has no use for a web view any more, and
            // should not sit through the rest of a warm-up to find that out.
            // The warm-up carries on; whatever it produces is shelved.
            Task { @MainActor in
                cancelWaiter(waiter)
            }
        }
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
        strip(webView)

        // Through the same funnel as a finished warm-up: a checkout already
        // waiting should be handed this one rather than sit through a warm-up
        // that has not landed yet. Shelved instead when nobody is waiting, and
        // dropped when there is no room.
        deliver(webView)

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

    /// Builds a web view and performs its first navigation on the Readium
    /// scheme, the cost every web view pays once.
    private static func makeWarmedWebView() async -> WebView? {
        let webView = makeWebView()
        return await warmUp(webView) ? webView : nil
    }

    /// Performs the first navigation on the Readium scheme, which every web
    /// view pays once.
    ///
    /// - Returns: Whether the navigation succeeded. A web view whose warm-up
    ///   failed has not paid that cost and is not worth pooling.
    private static func warmUp(_ webView: WebView) async -> Bool {
        let delegate = WarmupNavigationDelegate()
        webView.navigationDelegate = delegate
        defer { webView.navigationDelegate = nil }

        webView.load(URLRequest(url: WebViewServer.shared.warmupURL.url))
        return await delegate.wait()
    }
}

/// One pending warm-up, resolved by whichever of the warm-up itself or the
/// timeout gets there first.
@MainActor
private final class WarmupSlot {
    private var continuation: CheckedContinuation<WebView?, Never>?
    private var isResolved = false

    init(_ continuation: CheckedContinuation<WebView?, Never>) {
        self.continuation = continuation
    }

    /// - Returns: Whether this call is the one that resolved the slot.
    @discardableResult
    func resolve(_ webView: WebView?) -> Bool {
        guard !isResolved else {
            return false
        }

        isResolved = true
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(returning: webView)
        return true
    }
}

/// A checkout waiting for a warm-up, resolved by whichever of the warm-up or
/// its own cancellation gets there first.
@MainActor
final class CheckoutWaiter {
    private var continuation: CheckedContinuation<WebView?, Never>?
    private var isResolved = false

    /// Hands the waiter the continuation to resume.
    ///
    /// Resolves straight away if the checkout was cancelled before it got this
    /// far, which is possible for a task cancelled the moment it started.
    func attach(_ continuation: CheckedContinuation<WebView?, Never>) {
        guard !isResolved else {
            continuation.resume(returning: nil)
            return
        }

        self.continuation = continuation
    }

    /// - Returns: Whether this call is the one that resolved the waiter.
    @discardableResult
    func resolve(_ webView: WebView?) -> Bool {
        guard !isResolved else {
            return false
        }

        isResolved = true
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(returning: webView)
        return true
    }
}

/// Awaits the end of the warm-up navigation.
private final class WarmupNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var result: Bool?

    /// - Returns: Whether the navigation succeeded.
    func wait() async -> Bool {
        if let result {
            return result
        }

        return await withCheckedContinuation { continuation = $0 }
    }

    private func finish(succeeded: Bool) {
        guard result == nil else {
            return
        }

        result = succeeded
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: succeeded)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(succeeded: true)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        finish(succeeded: false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        finish(succeeded: false)
    }

    /// The web content process died, most likely to memory pressure during
    /// launch. No navigation callback is coming, so the warm-up is resolved
    /// here or it would never return at all.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(succeeded: false)
    }
}
