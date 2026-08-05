//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import WebKit
import XCTest

/// Creating a `WKWebView` spawns a web content process, so these tests keep
/// the number of real web views to a minimum.
// MARK: - Deterministic warm-ups

/// A warm-up the test drives itself.
///
/// Real warm-ups finish whenever WebKit says so, which makes the timing of a
/// checkout racing one impossible to pin down — and a test that waits on the
/// wrong side of that race hangs rather than fails.
@MainActor
private final class WarmupStub {
    private(set) var startedCount = 0
    private var pending: [CheckedContinuation<WebView?, Never>] = []

    /// Web views handed out, so a test can compare identities.
    private(set) var producedViews: [WebView] = []

    var isWaiting: Bool { !pending.isEmpty }

    /// When set, later warm-ups finish straight away instead of waiting to be
    /// driven, so a test can check the pool still works after a stall.
    var autoCompletes = false

    /// The factory to hand to `EPUBWebViewPool(capacity:warmup:)`.
    func factory() -> EPUBWebViewPool.WarmupFactory {
        { [self] in
            startedCount += 1

            if autoCompletes {
                let webView = WebView(configuration: WKWebViewConfiguration())
                producedViews.append(webView)
                return webView
            }

            return await withCheckedContinuation { pending.append($0) }
        }
    }

    /// Completes one warm-up successfully.
    func finishOne() {
        guard !pending.isEmpty else { return }
        let webView = WebView(configuration: WKWebViewConfiguration())
        producedViews.append(webView)
        pending.removeFirst().resume(returning: webView)
    }

    /// Completes one warm-up as a failure.
    func failOne() {
        guard !pending.isEmpty else { return }
        pending.removeFirst().resume(returning: nil)
    }

    func finishAll() {
        while !pending.isEmpty {
            finishOne()
        }
    }
}

@MainActor
final class EPUBWebViewPoolTests: XCTestCase {
    func testStartsEmpty() async {
        let sut = EPUBWebViewPool(capacity: 2)

        XCTAssertEqual(sut.count, 0)
        let webView = await sut.checkout(editingActions: makeEditingActions())
        XCTAssertNil(webView)
    }

    func testPrewarmFillsThePool() async {
        let sut = EPUBWebViewPool(capacity: 2)

        await sut.prewarm(count: 1)

        XCTAssertEqual(sut.count, 1)
    }

    func testPrewarmNeverExceedsCapacity() async {
        let sut = EPUBWebViewPool(capacity: 1)

        await sut.prewarm(count: 3)

        XCTAssertEqual(sut.count, 1)
    }

    func testCheckoutHandsOutAPrewarmedWebView() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)

        let webView = await sut.checkout(editingActions: makeEditingActions())

        XCTAssertNotNil(webView)
        XCTAssertEqual(sut.count, 0, "The web view should no longer be available")
        let second = await sut.checkout(editingActions: makeEditingActions())
        XCTAssertNil(second)
    }

    /// The whole point of the pool: a web view handed back by one navigator is
    /// served to the next one, instead of being torn down with its process.
    func testWebViewsAreReusedAcrossCheckouts() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)

        guard let first = await sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        sut.giveBack(first)
        let second = await sut.checkout(editingActions: makeEditingActions())

        XCTAssertTrue(second === first, "The returned web view was not handed out again")
    }

    func testGiveBackDropsWebViewsBeyondCapacity() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)
        guard let webView = await sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }

        sut.giveBack(webView)
        sut.giveBack(webView)

        XCTAssertEqual(sut.count, 1)
    }

    /// A recycled web view must not keep running the previous publication's
    /// scripts, nor keep delivering messages to its spread view.
    func testCheckoutClearsTheScriptsInstalledByThePreviousNavigator() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)
        guard let webView = await sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        webView.configuration.userContentController.addUserScript(
            WKUserScript(source: "window.leaked = true;", injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 1)

        sut.giveBack(webView)
        _ = await sut.checkout(editingActions: makeEditingActions())

        XCTAssertEqual(
            webView.configuration.userContentController.userScripts.count, 0,
            "The previous publication's user scripts survived the checkout"
        )
    }

    func testCheckoutDetachesTheWebViewFromThePreviousSpreadView() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)
        guard let webView = await sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        let container = UIView()
        container.addSubview(webView)

        sut.giveBack(webView)
        _ = await sut.checkout(editingActions: makeEditingActions())

        XCTAssertNil(webView.superview, "The web view is still attached to the previous spread view")
        XCTAssertNil(webView.navigationDelegate)
        XCTAssertNil(webView.uiDelegate)
    }

    /// A web view idling in the pool must not still carry the previous
    /// publication's scripts, delegates or rights: stripping only on the way
    /// out would keep them — and through them the publication's `UserRights` —
    /// alive for as long as the web view sits there.
    func testGiveBackStripsTheWebViewImmediately() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)
        guard let webView = await sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        let container = UIView()
        container.addSubview(webView)
        webView.configuration.userContentController.addUserScript(
            WKUserScript(source: "window.leaked = true;", injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        XCTAssertTrue(webView.isBoundToPublication)

        sut.giveBack(webView)

        XCTAssertFalse(webView.isBoundToPublication, "The publication's editing rights are still bound")
        XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 0)
        XCTAssertNil(webView.superview)
        XCTAssertNil(webView.navigationDelegate)
        XCTAssertNil(webView.uiDelegate)
    }

    func testCheckoutBindsThePublicationsEditingRights() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)

        let webView = await sut.checkout(editingActions: makeEditingActions())

        XCTAssertEqual(webView?.isBoundToPublication, true)
    }

    /// Pooled web views are bound to the shared server, and their storage is
    /// kept out of the persistent store.
    func testPooledWebViewsUseANonPersistentDataStore() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)

        let webView = await sut.checkout(editingActions: makeEditingActions())

        XCTAssertEqual(webView?.configuration.websiteDataStore.isPersistent, false)
    }

    // MARK: - Checking out during a warm-up

    /// A reader that opens a publication moments after launch finds the pool
    /// still filling. Waiting for the warm-up already under way beats starting
    /// a second one alongside it: it is part way through, and the two would
    /// otherwise compete for the device.
    func testCheckoutWaitsForAWarmupAlreadyInFlight() async {
        let sut = EPUBWebViewPool(capacity: 1)
        async let warming: Void = sut.prewarm(count: 1)
        await pump { sut.isWarmingUp }
        XCTAssertEqual(sut.count, 0, "The warm-up should not have finished yet")

        let webView = await sut.checkout(editingActions: makeEditingActions())
        await warming

        XCTAssertNotNil(webView, "The checkout gave up instead of waiting for the warm-up")
        XCTAssertEqual(webView?.isBoundToPublication, true)
    }

    /// Nothing to wait for means answering straight away, so the caller can
    /// get on with building its own.
    func testCheckoutReturnsNilWhenNothingIsWarmingUp() async {
        let sut = EPUBWebViewPool(capacity: 2)

        let webView = await sut.checkout(editingActions: makeEditingActions())

        XCTAssertNil(webView)
        XCTAssertFalse(sut.isWarmingUp)
    }


    // MARK: - Checking out against a driven warm-up

    /// Only as many checkouts as there are warm-ups in flight may wait. One
    /// more would be waiting for something that is never coming.
    func testCheckoutBeyondTheWarmupsInFlightReturnsNilRatherThanHanging() async {
        let stub = WarmupStub()
        let sut = EPUBWebViewPool(capacity: 1, warmup: stub.factory())
        async let warming: Void = sut.prewarm(count: 1)
        await pump { stub.isWaiting }

        async let firstCheckout = sut.checkout(editingActions: makeEditingActions())
        await pump { sut.hasWaitingCheckouts }

        // Nothing left in flight for this one to wait on.
        let second = await sut.checkout(editingActions: makeEditingActions())
        XCTAssertNil(second, "The second checkout had no warm-up left to wait for")

        stub.finishOne()
        let first = await firstCheckout
        await warming

        XCTAssertNotNil(first, "The first checkout should have been served by the warm-up")
    }

    /// A warm-up that fails must still release whoever was waiting on it, or
    /// the reader hangs instead of falling back to building its own.
    func testWaiterIsResumedWhenTheWarmupFails() async {
        let stub = WarmupStub()
        let sut = EPUBWebViewPool(capacity: 1, warmup: stub.factory())
        async let warming: Void = sut.prewarm(count: 1)
        await pump { stub.isWaiting }

        async let checkout = sut.checkout(editingActions: makeEditingActions())
        await pump { sut.hasWaitingCheckouts }

        stub.failOne()
        let webView = await checkout
        await warming

        XCTAssertNil(webView, "A failed warm-up should send the caller off to build its own")
        XCTAssertEqual(sut.count, 0)
    }

    /// The waiting checkout is served the moment its warm-up lands, rather
    /// than starting a second one alongside it.
    func testCheckoutIsServedByTheWarmupItWaitedFor() async {
        let stub = WarmupStub()
        let sut = EPUBWebViewPool(capacity: 1, warmup: stub.factory())
        async let warming: Void = sut.prewarm(count: 1)
        await pump { stub.isWaiting }

        async let checkout = sut.checkout(editingActions: makeEditingActions())
        await pump { sut.hasWaitingCheckouts }
        stub.finishOne()

        let webView = await checkout
        await warming

        XCTAssertEqual(stub.startedCount, 1, "A second web view was built instead of waiting")
        XCTAssertTrue(webView === stub.producedViews.first, "The waiter got a different web view")
        XCTAssertEqual(webView?.isBoundToPublication, true)
    }

    /// Waiters are served in the order they arrived.
    func testWaitersAreServedInOrder() async {
        let stub = WarmupStub()
        let sut = EPUBWebViewPool(capacity: 2, warmup: stub.factory())
        async let warming: Void = sut.prewarm(count: 2)
        await pump { stub.startedCount == 2 }

        async let firstCheckout = sut.checkout(editingActions: makeEditingActions())
        await pump { sut.hasWaitingCheckouts }
        async let secondCheckout = sut.checkout(editingActions: makeEditingActions())
        await pump { stub.startedCount == 2 && sut.hasWaitingCheckouts }

        stub.finishAll()
        let first = await firstCheckout
        let second = await secondCheckout
        await warming

        XCTAssertEqual(first === stub.producedViews.first, true, "The oldest waiter was not served first")
        XCTAssertNotNil(second)
    }


    // MARK: - Warm-ups that never come back

    /// A web content process can die mid warm-up, taking its navigation
    /// callbacks with it. Without a backstop the warm-up never returns, the
    /// pool's in-flight count never drops, every later refill declines to run
    /// and any waiter waits for the rest of the process's life.
    func testAStalledWarmupReleasesItsWaiterAndLeavesThePoolUsable() async {
        let stub = WarmupStub()
        let sut = EPUBWebViewPool(capacity: 1, warmupTimeout: 0.2, warmup: stub.factory())

        async let warming: Void = sut.prewarm(count: 1)
        await pump { stub.isWaiting }
        async let checkout = sut.checkout(editingActions: makeEditingActions())
        await pump { sut.hasWaitingCheckouts }

        // The stub is never driven: only the timeout can resolve this.
        let webView = await checkout
        await warming

        XCTAssertNil(webView, "The waiter was never released")
        XCTAssertFalse(sut.isWarmingUp, "The in-flight count never came back down")

        // And the pool is not wedged for good.
        stub.autoCompletes = true
        await sut.prewarm(count: 1)
        XCTAssertEqual(sut.count, 1, "No later warm-up could run after the stall")
    }

    // MARK: - Cancellation

    /// A load chain that gets cancelled has no use for a web view any more and
    /// must not sit through the rest of a warm-up to discover that.
    func testCancellingAWaitingCheckoutReleasesItPromptly() async {
        let stub = WarmupStub()
        let sut = EPUBWebViewPool(capacity: 1, warmup: stub.factory())
        async let warming: Void = sut.prewarm(count: 1)
        await pump { stub.isWaiting }

        let checkout = Task { await sut.checkout(editingActions: makeEditingActions()) }
        await pump { sut.hasWaitingCheckouts }

        checkout.cancel()
        let webView = await checkout.value

        XCTAssertNil(webView, "A cancelled checkout should not wait the warm-up out")
        await pump { !sut.hasWaitingCheckouts }
        XCTAssertFalse(sut.hasWaitingCheckouts, "The cancelled waiter was left in the queue")

        // The warm-up carries on, and what it produces is shelved.
        stub.finishOne()
        await warming
        XCTAssertEqual(sut.count, 1, "The warm-up was lost along with its cancelled waiter")
    }

    // MARK: - Returns and waiters

    /// A web view coming back is ready now, whereas the warm-up a checkout is
    /// waiting on may be seconds away. The waiter should get the ready one.
    func testGiveBackServesAWaitingCheckoutBeforeShelving() async {
        let stub = WarmupStub()
        let sut = EPUBWebViewPool(capacity: 2, warmup: stub.factory())
        async let warming: Void = sut.prewarm(count: 2)
        await pump { stub.startedCount == 2 }

        stub.finishOne()
        await pump { sut.count == 1 }
        guard let borrowed = await sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected the finished warm-up to be available")
        }

        // Nothing on the shelf, so this one waits for the second warm-up.
        async let waiting = sut.checkout(editingActions: makeEditingActions())
        await pump { sut.hasWaitingCheckouts }

        sut.giveBack(borrowed)
        let served = await waiting

        XCTAssertTrue(served === borrowed, "The returned web view was shelved while a checkout waited")

        stub.finishAll()
        await warming
    }

    // MARK: - Yielding to the reader

    /// Warming up competes with the publication the reader is opening, badly
    /// enough to make the open slower than having no pool at all. Once a web
    /// view is on loan the pool must stop building any.
    func testPrewarmDoesNothingWhileWebViewsAreBorrowed() async {
        let sut = EPUBWebViewPool(capacity: 2)
        await sut.prewarm(count: 1)
        _ = await sut.checkout(editingActions: makeEditingActions())
        XCTAssertEqual(sut.count, 0)

        await sut.prewarm(count: 2)

        XCTAssertEqual(sut.count, 0, "The pool built web views while a reader was using them")
    }

    /// A reading session needs no new stock: the web views come back at
    /// teardown, which restocks the pool for free.
    func testReturnsRestockThePoolWithoutBuildingAnything() async {
        let sut = EPUBWebViewPool(capacity: 2)
        await sut.prewarm(count: 2)
        guard
            let first = await sut.checkout(editingActions: makeEditingActions()),
            let second = await sut.checkout(editingActions: makeEditingActions())
        else {
            return XCTFail("Expected two prewarmed web views")
        }
        XCTAssertEqual(sut.count, 0)

        sut.giveBack(first)
        sut.giveBack(second)

        XCTAssertEqual(sut.count, 2)
        let restocked = [
            await sut.checkout(editingActions: makeEditingActions()),
            await sut.checkout(editingActions: makeEditingActions()),
        ]
        XCTAssertEqual(
            Set(restocked.compactMap { $0.map(ObjectIdentifier.init) }),
            Set([first, second].map(ObjectIdentifier.init)),
            "The pool built replacements instead of reusing the returned web views"
        )
    }

    /// Returning only some of the borrowed web views means the reader is still
    /// on screen, so the pool keeps out of the way.
    func testPoolStaysIdleWhileSomeWebViewsAreStillBorrowed() async {
        let sut = EPUBWebViewPool(capacity: 2)
        await sut.prewarm(count: 2)
        guard
            let first = await sut.checkout(editingActions: makeEditingActions()),
            await sut.checkout(editingActions: makeEditingActions()) != nil
        else {
            return XCTFail("Expected two prewarmed web views")
        }

        sut.giveBack(first)
        await sut.prewarm(count: 2)

        XCTAssertEqual(sut.count, 1, "The pool built a web view while one was still on loan")
    }

    /// Closing the reader both returns web views and asks for a top-up. The
    /// two together must not take the pool past its capacity.
    func testReturnsAndAnExplicitPrewarmDoNotOverfillThePool() async {
        let sut = EPUBWebViewPool(capacity: 2)
        await sut.prewarm(count: 2)
        guard
            let first = await sut.checkout(editingActions: makeEditingActions()),
            let second = await sut.checkout(editingActions: makeEditingActions())
        else {
            return XCTFail("Expected two prewarmed web views")
        }

        // The order a reader dismissal produces: the top-up is asked for while
        // teardown is still handing web views back.
        async let topUp: Void = sut.prewarm(count: 2)
        sut.giveBack(first)
        sut.giveBack(second)
        await topUp

        XCTAssertEqual(sut.count, 2, "The pool grew past its capacity")
    }

    func testPrewarmRestocksOnceEverythingIsBack() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)
        guard let webView = await sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        sut.giveBack(webView)

        await sut.prewarm(count: 1)

        XCTAssertEqual(sut.count, 1)
    }

    // MARK: - Helpers

    /// Yields to the main actor until `condition` holds, or the budget runs out.
    @discardableResult
    private func pump(iterations: Int = 200, until condition: () -> Bool) async -> Bool {
        for _ in 0 ..< iterations {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return condition()
    }

    private func makeEditingActions() -> EditingActionsController {
        EditingActionsController(
            actions: EditingAction.defaultActions,
            publication: Publication(manifest: Manifest(metadata: Metadata(title: "Test")))
        )
    }
}
