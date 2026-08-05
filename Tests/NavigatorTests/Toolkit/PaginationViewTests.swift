//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import UIKit
import XCTest

@MainActor
final class PaginationViewTests: XCTestCase {
    private let pageSize = CGRect(x: 0, y: 0, width: 320, height: 480)

    /// The delegate must be notified as soon as the *current* page finished
    /// loading, without waiting for the preloaded neighbours.
    func testDelegateNotifiedWhenCurrentPageLoadsBeforePreloads() async {
        let didUpdateViews = expectation(description: "paginationViewDidUpdateViews called")
        didUpdateViews.assertForOverFulfill = false

        let spy = PaginationViewDelegateSpy()
        let sut = makeSUT(delegate: spy)
        sut.reloadAtIndex(5, location: .start, pageCount: 100, readingProgression: .ltr)

        // Wait for the current page to be created and to start loading.
        let currentPageIsLoading = await pump { spy.pageViews[5]?.isLoading == true }
        XCTAssertTrue(currentPageIsLoading, "The current page (5) never started loading")

        // Arm the expectation only now, so it cannot be satisfied by a
        // notification that happened before the current page finished loading.
        let updateCountBeforeRelease = spy.didUpdateViewsCallCount
        spy.onDidUpdateViews = { didUpdateViews.fulfill() }

        // Let the current page finish loading. Every other page stays gated.
        spy.pageViews[5]?.release()

        await fulfillment(of: [didUpdateViews], timeout: 1.0)

        XCTAssertGreaterThan(
            spy.didUpdateViewsCallCount, updateCountBeforeRelease,
            "The delegate was not notified as a result of the current page finishing"
        )
        XCTAssertEqual(spy.pageViews[5]?.didFinishLoading, true)

        // What matters is the state captured *at the moment* the delegate
        // fired: page 5 must be the only page that had finished loading. This
        // pins the ordering whether the neighbours are preloaded serially or
        // concurrently, and cannot pass vacuously — page 5 must be present.
        let firstUpdateAfterRelease = spy.updates
            .dropFirst(updateCountBeforeRelease)
            .first
        XCTAssertEqual(
            firstUpdateAfterRelease?.finishedIndices, [5],
            "The delegate should be notified once the current page is loaded, not once its neighbours are"
        )

        // Unblock the remaining pages so no continuation is left dangling.
        spy.releaseAll()
        await pump { !spy.hasLoadingPageViews }
    }

    /// A single reload must not request the same page index twice: re-requesting
    /// indices makes the preloading cost grow superlinearly.
    func testEachIndexRequestedAtMostOncePerReload() async {
        let spy = PaginationViewDelegateSpy()
        let sut = makeSUT(delegate: spy)

        sut.reloadAtIndex(5, location: .start, pageCount: 100, readingProgression: .ltr)

        // Drain the whole loading queue.
        for _ in 0 ..< 20 {
            await pump { spy.hasLoadingPageViews }
            spy.releaseAll()
        }

        XCTAssertFalse(spy.requestedIndices.isEmpty, "No page was ever requested")
        XCTAssertEqual(
            spy.pageViews[5]?.goCallCount, 1,
            "The current page was loaded more than once for a single reload"
        )

        let duplicates = spy.requestedIndices
            .reduce(into: [Int: Int]()) { $0[$1, default: 0] += 1 }
            .filter { $0.value > 1 }
            .keys
            .sorted()

        XCTAssertEqual(
            duplicates, [],
            "Indices requested more than once: \(duplicates), full sequence: \(spy.requestedIndices)"
        )
    }

    /// Navigating away leaves the pages queued for the *previous* position
    /// still pending. They must not be loaded before the new current page:
    /// the page the reader is looking at always comes first.
    func testNavigatingDropsPagesQueuedForThePreviousPosition() async {
        let spy = PaginationViewDelegateSpy()
        let sut = makeSUT(delegate: spy)

        // Queues [5, 6, 4] and gets stuck loading page 5, leaving 6 and 4
        // pending in the queue.
        sut.reloadAtIndex(5, location: .start, pageCount: 100, readingProgression: .ltr)
        let firstPageIsLoading = await pump { spy.pageViews[5]?.isLoading == true }
        XCTAssertTrue(firstPageIsLoading, "Page 5 never started loading")

        // Jump far away, the way a table of contents entry does.
        let requestsBeforeJump = spy.requestedIndices.count
        let jump = Task { await sut.goToIndex(50, location: .start, options: NavigatorGoOptions(animated: false)) }
        defer { jump.cancel() }

        // Release the stale in-flight page so the loading chain can move on.
        await pump { spy.requestedIndices.count > requestsBeforeJump }
        spy.releaseAll()
        await pump { spy.requestedIndices.count > requestsBeforeJump }

        let indexLoadedAfterJump = spy.requestedIndices.dropFirst(requestsBeforeJump).first
        XCTAssertEqual(
            indexLoadedAfterJump, 50,
            "Pages queued for the previous position were loaded before the new current page"
        )
    }

    /// Reloading cancels the in-flight loading task. The cancelled chain must
    /// stop: it may finish the page it already started, but it must not keep
    /// draining the queue nor notify the delegate about the new, still blank,
    /// current page.
    func testReloadStopsTheCancelledLoadingChain() async {
        let spy = PaginationViewDelegateSpy()
        let sut = makeSUT(delegate: spy)

        // First reload queues [5, 6, 4] and gets stuck loading page 5.
        sut.reloadAtIndex(5, location: .start, pageCount: 100, readingProgression: .ltr)
        let firstPageIsLoading = await pump { spy.pageViews[5]?.isLoading == true }
        XCTAssertTrue(firstPageIsLoading, "Page 5 never started loading")

        // Jump elsewhere while page 5 is still in flight. This cancels the
        // loading task and queues [50, 51, 49] instead.
        let requestsBeforeReload = spy.requestedIndices.count
        let updatesBeforeReload = spy.updates.count
        sut.reloadAtIndex(50, location: .start, pageCount: 100, readingProgression: .ltr)

        let newCurrentPageIsLoading = await pump { spy.pageViews[50]?.isLoading == true }
        XCTAssertTrue(newCurrentPageIsLoading, "Page 50 never started loading after the reload")

        // Let the *stale* page finish. Its chain is cancelled, so it must not
        // pick up any further work — page 51 belongs to the new chain, which is
        // still busy with page 50.
        spy.pageViews[5]?.release()
        await pump { spy.pageViews[51] != nil }

        XCTAssertEqual(spy.pageViews[5]?.didFinishLoading, true, "Page 5 was never released")
        XCTAssertEqual(spy.pageViews[50]?.isLoading, true, "The new chain should still be loading page 50")
        XCTAssertNil(
            spy.pageViews[51],
            "The cancelled chain kept draining the queue and started loading page 51"
        )

        // Drain everything that remains.
        for _ in 0 ..< 20 {
            await pump { spy.hasLoadingPageViews }
            spy.releaseAll()
        }

        let indicesAfterReload = Set(spy.requestedIndices.dropFirst(requestsBeforeReload))
        XCTAssertFalse(indicesAfterReload.isEmpty, "No page was requested after the reload")
        XCTAssertTrue(
            indicesAfterReload.isSubset(of: [49, 50, 51]),
            "Stale indices were loaded after the reload: \(indicesAfterReload.sorted())"
        )

        let updatesAfterReload = Array(spy.updates.dropFirst(updatesBeforeReload))
        XCTAssertFalse(updatesAfterReload.isEmpty, "The delegate was never notified after the reload")
        let blankNotifications = updatesAfterReload.filter { !$0.currentPageDidFinishLoading }
        XCTAssertEqual(
            blankNotifications, [],
            "The delegate was notified while the current page was still blank: \(blankNotifications)"
        )
    }

    /// Page views that fall out of the pre-load window are handed back to the
    /// delegate, so it can re-target them instead of paying for a brand new
    /// web view.
    func testFlushedPageViewsAreHandedBackAndCanBeRecycled() async {
        let spy = PaginationViewDelegateSpy()
        spy.recyclesViews = true
        let sut = makeSUT(delegate: spy)

        sut.reloadAtIndex(5, location: .start, pageCount: 100, readingProgression: .ltr)
        await drain(spy)

        XCTAssertEqual(spy.displayedViews.keys.sorted(), [4, 5, 6], "Expected the current page and its neighbours")
        XCTAssertEqual(spy.createdViewCount, 3)
        XCTAssertEqual(spy.returnedIndices, [], "Nothing should have been flushed yet")

        // Jump far away: none of the loaded pages stay in the window.
        let jump = Task { await sut.goToIndex(50, location: .start, options: NavigatorGoOptions(animated: false)) }
        defer { jump.cancel() }
        await drain(spy)

        XCTAssertEqual(
            spy.returnedIndices.sorted(), [4, 5, 6],
            "The flushed page views were discarded instead of being handed back"
        )
        XCTAssertEqual(
            spy.createdViewCount, 3,
            "New page views were built even though \(spy.returnedIndices.count) were available for reuse"
        )
        XCTAssertEqual(spy.displayedViews.keys.sorted(), [49, 50, 51])

        let reused = Set(spy.displayedViews.values.map(ObjectIdentifier.init))
        let handedBack = Set(spy.returnedViews.map(ObjectIdentifier.init))
        XCTAssertEqual(reused, handedBack, "The pages now on screen are not the recycled instances")
    }

    /// Building a page view suspends, so the pagination can be reloaded while
    /// one is being made. The page that arrives late belongs to the position
    /// the reader has left: it must neither be displayed nor dropped on the
    /// floor — the delegate gets it back so it can recycle it.
    func testPageViewArrivingAfterAReloadIsHandedBackInsteadOfDisplayed() async {
        let spy = PaginationViewDelegateSpy()
        spy.gatesPageViewCreation = true
        let sut = makeSUT(delegate: spy)

        sut.reloadAtIndex(5, location: .start, pageCount: 100, readingProgression: .ltr)
        let isBuildingPage5 = await pump { spy.hasPendingPageViewCreation }
        XCTAssertTrue(isBuildingPage5, "Page 5 was never requested")
        XCTAssertEqual(spy.requestedIndices, [5])

        // Jump elsewhere while page 5 is still being built. This cancels the
        // loading chain that asked for it.
        sut.reloadAtIndex(50, location: .start, pageCount: 100, readingProgression: .ltr)
        let updatesBeforeRelease = spy.updates.count

        spy.releasePageViewCreation()
        await pump { spy.returnedIndices.contains(5) }

        XCTAssertNil(sut.loadedViews[5], "A page from the abandoned position was put on screen")
        XCTAssertTrue(
            spy.returnedIndices.contains(5),
            "The page built for the abandoned position was dropped instead of handed back"
        )

        let staleUpdates = spy.updates
            .dropFirst(updatesBeforeRelease)
            .filter { $0.currentIndex == 5 }
        XCTAssertEqual(staleUpdates, [], "The cancelled chain reported progress after the reload")

        spy.gatesPageViewCreation = false
        spy.releasePageViewCreation()
        await drain(spy)
    }

    /// Reloads that interrupt page creation must leave nothing behind: every
    /// page view built is either on screen or has been given back, never
    /// silently dropped along with whatever it holds.
    func testNoPageViewIsStrandedWhenReloadsInterruptCreation() async {
        let spy = PaginationViewDelegateSpy()
        spy.gatesPageViewCreation = true
        let sut = makeSUT(delegate: spy)

        sut.reloadAtIndex(5, location: .start, pageCount: 100, readingProgression: .ltr)
        await pump { spy.hasPendingPageViewCreation }
        sut.reloadAtIndex(50, location: .start, pageCount: 100, readingProgression: .ltr)
        await pump { spy.requestedIndices.contains(50) }
        sut.reloadAtIndex(80, location: .start, pageCount: 100, readingProgression: .ltr)

        spy.gatesPageViewCreation = false
        for _ in 0 ..< 20 {
            spy.releasePageViewCreation()
            await pump { spy.hasLoadingPageViews }
            spy.releaseAll()
        }

        let built = Set(spy.createdViews.map(ObjectIdentifier.init))
        let onScreen = Set(sut.loadedViews.values.compactMap { ($0 as? GatedPageView).map(ObjectIdentifier.init) })
        let handedBack = Set(spy.returnedViews.map(ObjectIdentifier.init))

        XCTAssertFalse(built.isEmpty, "No page view was ever built")
        XCTAssertEqual(
            built.subtracting(onScreen).subtracting(handedBack), [],
            "Page views were dropped instead of being displayed or handed back"
        )
    }

    // MARK: - Helpers

    private func makeSUT(delegate: PaginationViewDelegateSpy) -> PaginationView {
        let sut = PaginationView(
            frame: pageSize,
            preloadPreviousPositionCount: 1,
            preloadNextPositionCount: 1,
            isScrollEnabled: true
        )
        sut.delegate = delegate
        return sut
    }

    /// Releases every gated page view until nothing is loading anymore.
    private func drain(_ spy: PaginationViewDelegateSpy, iterations: Int = 20) async {
        for _ in 0 ..< iterations {
            await pump { spy.hasLoadingPageViews }
            spy.releaseAll()
        }
    }

    /// Yields to the main actor until `condition` holds, or the iteration
    /// budget is exhausted.
    @discardableResult
    private func pump(iterations: Int = 50, until condition: () -> Bool) async -> Bool {
        for _ in 0 ..< iterations {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return condition()
    }
}

/// A `PageView` whose loading is gated by the test: `go(to:animated:)` suspends
/// until `release()` is called.
@MainActor
private final class GatedPageView: UIView, PageView {
    private var continuation: CheckedContinuation<Void, Never>?

    private(set) var didFinishLoading = false
    private(set) var goCallCount = 0

    /// Whether `go(to:animated:)` is currently suspended, waiting for `release()`.
    var isLoading: Bool { continuation != nil }

    func go(to location: PageLocation, animated: Bool) async {
        goCallCount += 1
        // A `CheckedContinuation` must be resumed exactly once. If production
        // code starts a second load before the first one finished, resume the
        // pending one rather than dropping it on the floor.
        resumePendingContinuation()
        await withCheckedContinuation { continuation = $0 }
        didFinishLoading = true
    }

    func release() {
        resumePendingContinuation()
    }

    private func resumePendingContinuation() {
        guard let pending = continuation else {
            return
        }
        continuation = nil
        pending.resume()
    }
}

/// State of the pagination view captured at the moment the delegate was
/// notified.
private struct UpdateSnapshot: Equatable {
    let currentIndex: Int
    /// Whether the page the pagination view considers current had finished
    /// loading. Notifying while this is false means publishing a blank page.
    let currentPageDidFinishLoading: Bool
    let finishedIndices: [Int]
}

@MainActor
private final class PaginationViewDelegateSpy: PaginationViewDelegate {
    /// Every index passed to `pageViewAtIndex`, in call order.
    private(set) var requestedIndices: [Int] = []

    /// Last page view served for each index. Never pruned, so a test can still
    /// reach a view after the pagination view stopped displaying it.
    private(set) var pageViews: [Int: GatedPageView] = [:]

    /// Page views the pagination view is currently displaying.
    private(set) var displayedViews: [Int: GatedPageView] = [:]

    /// Every page view ever built, including those no longer displayed.
    private(set) var createdViews: [GatedPageView] = []

    var createdViewCount: Int { createdViews.count }

    /// Page views handed back through `didEndDisplayingView`, in call order.
    private(set) var returnedIndices: [Int] = []
    private(set) var returnedViews: [GatedPageView] = []

    /// When enabled, page views handed back are pooled and served again on the
    /// next request, the way the EPUB navigator recycles its spread views.
    var recyclesViews = false
    private var pool: [GatedPageView] = []

    /// State captured at each `paginationViewDidUpdateViews` call, in call order.
    private(set) var updates: [UpdateSnapshot] = []

    var didUpdateViewsCallCount: Int { updates.count }

    var onDidUpdateViews: (() -> Void)?

    var hasLoadingPageViews: Bool {
        createdViews.contains { $0.isLoading }
    }

    func releaseAll() {
        for view in createdViews {
            view.release()
        }
    }

    /// When enabled, `pageViewAtIndex` suspends until `releasePageViewCreation`
    /// is called, so a test can act while the pagination view is mid-await.
    var gatesPageViewCreation = false
    private var creationGates: [CheckedContinuation<Void, Never>] = []

    var hasPendingPageViewCreation: Bool { !creationGates.isEmpty }

    func releasePageViewCreation() {
        let gates = creationGates
        creationGates = []
        for gate in gates {
            gate.resume()
        }
    }

    func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) async -> (UIView & PageView)? {
        requestedIndices.append(index)

        if gatesPageViewCreation {
            await withCheckedContinuation { creationGates.append($0) }
        }

        let view: GatedPageView
        if recyclesViews, !pool.isEmpty {
            view = pool.removeFirst()
        } else {
            view = GatedPageView()
            createdViews.append(view)
        }

        pageViews[index] = view
        displayedViews[index] = view
        return view
    }

    func paginationView(_ paginationView: PaginationView, didEndDisplayingView view: UIView & PageView, atIndex index: Int) {
        guard let view = view as? GatedPageView else {
            return
        }
        returnedIndices.append(index)
        returnedViews.append(view)
        displayedViews.removeValue(forKey: index)

        if recyclesViews {
            pool.append(view)
        }
    }

    func paginationViewDidUpdateViews(_ paginationView: PaginationView) {
        let currentPage = paginationView.loadedViews[paginationView.currentIndex] as? GatedPageView
        updates.append(UpdateSnapshot(
            currentIndex: paginationView.currentIndex,
            currentPageDidFinishLoading: currentPage?.didFinishLoading == true,
            finishedIndices: pageViews
                .filter { $0.value.didFinishLoading }
                .keys
                .sorted()
        ))
        onDidUpdateViews?()
    }

    func paginationView(_ paginationView: PaginationView, positionCountAtIndex index: Int) -> Int {
        1
    }
}
