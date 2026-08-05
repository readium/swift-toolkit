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
@MainActor
final class EPUBWebViewPoolTests: XCTestCase {
    func testStartsEmpty() {
        let sut = EPUBWebViewPool(capacity: 2)

        XCTAssertEqual(sut.count, 0)
        XCTAssertNil(sut.checkout(editingActions: makeEditingActions()))
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

        let webView = sut.checkout(editingActions: makeEditingActions())

        XCTAssertNotNil(webView)
        XCTAssertEqual(sut.count, 0, "The web view should no longer be available")
        XCTAssertNil(sut.checkout(editingActions: makeEditingActions()))
    }

    /// The whole point of the pool: a web view handed back by one navigator is
    /// served to the next one, instead of being torn down with its process.
    func testWebViewsAreReusedAcrossCheckouts() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)

        guard let first = sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        sut.giveBack(first)
        let second = sut.checkout(editingActions: makeEditingActions())

        XCTAssertTrue(second === first, "The returned web view was not handed out again")
    }

    func testGiveBackDropsWebViewsBeyondCapacity() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)
        guard let webView = sut.checkout(editingActions: makeEditingActions()) else {
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
        guard let webView = sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        webView.configuration.userContentController.addUserScript(
            WKUserScript(source: "window.leaked = true;", injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 1)

        sut.giveBack(webView)
        _ = sut.checkout(editingActions: makeEditingActions())

        XCTAssertEqual(
            webView.configuration.userContentController.userScripts.count, 0,
            "The previous publication's user scripts survived the checkout"
        )
    }

    func testCheckoutDetachesTheWebViewFromThePreviousSpreadView() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)
        guard let webView = sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        let container = UIView()
        container.addSubview(webView)

        sut.giveBack(webView)
        _ = sut.checkout(editingActions: makeEditingActions())

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
        guard let webView = sut.checkout(editingActions: makeEditingActions()) else {
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

        let webView = sut.checkout(editingActions: makeEditingActions())

        XCTAssertEqual(webView?.isBoundToPublication, true)
    }

    /// Pooled web views are bound to the shared server, and their storage is
    /// kept out of the persistent store.
    func testPooledWebViewsUseANonPersistentDataStore() async {
        let sut = EPUBWebViewPool(capacity: 1)
        await sut.prewarm(count: 1)

        let webView = sut.checkout(editingActions: makeEditingActions())

        XCTAssertEqual(webView?.configuration.websiteDataStore.isPersistent, false)
    }

    // MARK: - Yielding to the reader

    /// Warming up competes with the publication the reader is opening, badly
    /// enough to make the open slower than having no pool at all. Once a web
    /// view is on loan the pool must stop building any.
    func testPrewarmDoesNothingWhileWebViewsAreBorrowed() async {
        let sut = EPUBWebViewPool(capacity: 2)
        await sut.prewarm(count: 1)
        _ = sut.checkout(editingActions: makeEditingActions())
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
            let first = sut.checkout(editingActions: makeEditingActions()),
            let second = sut.checkout(editingActions: makeEditingActions())
        else {
            return XCTFail("Expected two prewarmed web views")
        }
        XCTAssertEqual(sut.count, 0)

        sut.giveBack(first)
        sut.giveBack(second)

        XCTAssertEqual(sut.count, 2)
        let restocked = [
            sut.checkout(editingActions: makeEditingActions()),
            sut.checkout(editingActions: makeEditingActions()),
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
            let first = sut.checkout(editingActions: makeEditingActions()),
            sut.checkout(editingActions: makeEditingActions()) != nil
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
            let first = sut.checkout(editingActions: makeEditingActions()),
            let second = sut.checkout(editingActions: makeEditingActions())
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
        guard let webView = sut.checkout(editingActions: makeEditingActions()) else {
            return XCTFail("Expected a prewarmed web view")
        }
        sut.giveBack(webView)

        await sut.prewarm(count: 1)

        XCTAssertEqual(sut.count, 1)
    }

    // MARK: - Helpers

    private func makeEditingActions() -> EditingActionsController {
        EditingActionsController(
            actions: EditingAction.defaultActions,
            publication: Publication(manifest: Manifest(metadata: Metadata(title: "Test")))
        )
    }
}
