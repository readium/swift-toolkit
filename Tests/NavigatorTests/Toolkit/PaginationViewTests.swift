//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing
import TestSupport
import UIKit

@MainActor struct PaginationViewTests {
    /// Moving to a preloaded page notifies the delegate without waiting for
    /// the next page to load.
    @Test func movingToAPreloadedPageNotifiesBeforeThePreloading() async {
        let (view, delegate) = await makePaginationView(pageCount: 3)

        delegate.blockedIndexes = [2]
        _ = await view.goToIndex(1, location: .start, options: .init(animated: false))
        #expect(await delegate.nextEvent() == .update(index: 1, isCurrentPageLoading: false))
        #expect(await delegate.nextEvent() == .loading(index: 2))

        delegate.views[2]?.finishLoading()
        #expect(await delegate.nextEvent() == .update(index: 1, isCurrentPageLoading: false))
    }

    /// A page which is not loaded yet, or goes to a locator, reports its
    /// progression after loading or scrolling, so the delegate is notified
    /// once all the pages are loaded.
    @Test(arguments: [
        (2, PageLocation.start),
        (1, PageLocation.locator(Locator(href: AnyURL(string: "1")!, mediaType: .xhtml))),
    ])
    func otherPagesNotifyOnceAllThePagesAreLoaded(index: Int, location: PageLocation) async {
        let (view, delegate) = await makePaginationView(pageCount: 4)

        delegate.blockedIndexes = [index + 1]
        _ = await view.goToIndex(index, location: location, options: .init(animated: false))
        #expect(await delegate.nextEvent() == .loading(index: index + 1))

        delegate.views[index + 1]?.finishLoading()
        #expect(await delegate.nextEvent() == .update(index: index, isCurrentPageLoading: false))
    }

    /// Coming back to a page before it moved again waits for its move, as
    /// the user might have scrolled it.
    @Test func comingBackToAPageWaitsForItsMove() async {
        let (view, delegate) = await makePaginationView(pageCount: 3, preloadPreviousPositionCount: 1)

        // Moves to the second page, without moving the first one back to its
        // end, as the loading is stuck on the third one.
        delegate.blockedIndexes = [2]
        _ = await view.goToIndex(1, location: .start, options: .init(animated: false))
        #expect(await delegate.nextEvent() == .update(index: 1, isCurrentPageLoading: false))
        #expect(await delegate.nextEvent() == .loading(index: 2))

        delegate.views[1]?.blockNextMove()
        _ = await view.goToIndex(0, location: .start, options: .init(animated: false))
        #expect(await delegate.nextEvent() == .loading(index: 1))

        delegate.views[1]?.finishLoading()
        #expect(await delegate.nextEvent() == .update(index: 0, isCurrentPageLoading: false))
        delegate.views[2]?.finishLoading()
    }

    /// A reload cancels the loading in progress, which stops without taking
    /// the reloaded pages and without notifying the delegate, even when it
    /// was moving the settled current page.
    @Test(arguments: [false, true])
    func reloadingCancelsTheLoadingInProgress(reloadsTheSamePage: Bool) async throws {
        let (view, delegate) = await makePaginationView(pageCount: 4)
        let index = reloadsTheSamePage ? 1 : 2

        let movingView = try #require(delegate.views[1])
        movingView.blockNextMove()
        _ = await view.goToIndex(1, location: .start, options: .init(animated: false))
        #expect(await delegate.nextEvent() == .loading(index: 1))

        // The cancelled loading resumes before the new one starts.
        delegate.blockedIndexes = [index]
        movingView.finishLoading()
        view.reloadAtIndex(index, location: .start, pageCount: 4, readingProgression: .ltr)
        #expect(await delegate.nextEvent() == .loading(index: index))

        delegate.views[index]?.finishLoading()
        #expect(await delegate.nextEvent() == .update(index: index, isCurrentPageLoading: false))
    }

    /// Moving into a window while the current page loads, the first time
    /// or after leaving it, notifies the delegate once the page is shown.
    @Test(arguments: [false, true])
    func movingIntoAWindowWaitsForTheCurrentPage(leavesTheWindow: Bool) async {
        let (view, delegate) = await makePaginationView(pageCount: 3, blockedIndexes: [0])
        // Removing the view itself from its superview would drop its pages.
        let container = UIView(frame: view.frame)
        container.addSubview(view)

        let window = UIWindow(frame: view.frame)
        window.addSubview(container)
        if leavesTheWindow {
            container.removeFromSuperview()
            window.addSubview(container)
        }
        delegate.views[0]?.finishLoading()

        #expect(await delegate.nextEvent() == .update(index: 0, isCurrentPageLoading: false))
    }

    /// Moving to another page drops the pages left to load which are not
    /// preloaded anymore.
    @Test func movingDropsThePagesLeftToLoad() async {
        let (view, delegate) = await makePaginationView(pageCount: 6, preloadNextPositionCount: 2, blockedIndexes: [1])

        delegate.blockedIndexes = []
        _ = await view.goToIndex(3, location: .start, options: .init(animated: false))
        #expect(await delegate.nextEvent() == .update(index: 3, isCurrentPageLoading: false))
        #expect(delegate.views[2] == nil)

        delegate.views[1]?.finishLoading()
    }

    /// Returns a pagination view at the first page, once its pages are loaded
    /// or one of the `blockedIndexes` is loading.
    private func makePaginationView(
        pageCount: Int,
        preloadPreviousPositionCount: Int = 0,
        preloadNextPositionCount: Int = 1,
        blockedIndexes: Set<Int> = []
    ) async -> (PaginationView, FakeDelegate) {
        let view = PaginationView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            preloadPreviousPositionCount: preloadPreviousPositionCount,
            preloadNextPositionCount: preloadNextPositionCount,
            isScrollEnabled: true
        )
        let delegate = FakeDelegate()
        delegate.blockedIndexes = blockedIndexes
        view.delegate = delegate
        view.reloadAtIndex(0, location: .start, pageCount: pageCount, readingProgression: .ltr)
        await delegate.skipEvents { event in
            if case let .loading(index) = event {
                blockedIndexes.contains(index)
            } else {
                blockedIndexes.isEmpty
            }
        }
        return (view, delegate)
    }
}

@MainActor private final class FakeDelegate: PaginationViewDelegate {
    enum Event: Equatable, Sendable {
        /// The delegate was notified.
        case update(index: Int, isCurrentPageLoading: Bool)
        /// A blocked page started to load.
        case loading(index: Int)
    }

    /// Indexes of the pages whose creation waits for `finishLoading()`.
    var blockedIndexes: Set<Int> = []
    private(set) var views: [Int: FakePageView] = [:]

    private let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    func nextEvent() async -> Event? {
        await events.first(within: .testTimeout)
    }

    /// Skips the events up to the first one matching `condition`.
    func skipEvents(until condition: @escaping @Sendable (Event) -> Bool) async {
        _ = await events.first(within: .testTimeout, where: condition)
    }

    func paginationView(_ paginationView: PaginationView, pageViewAtIndex index: Int) -> (UIView & PageView)? {
        let view = FakePageView(isBlocked: blockedIndexes.contains(index)) { [continuation] in
            continuation.yield(.loading(index: index))
        }
        views[index] = view
        return view
    }

    func paginationViewDidUpdateViews(_ paginationView: PaginationView) {
        continuation.yield(.update(
            index: paginationView.currentIndex,
            isCurrentPageLoading: (paginationView.currentView as? FakePageView)?.isLoading ?? false
        ))
    }

    func paginationView(_ paginationView: PaginationView, positionCountAtIndex index: Int) -> Int {
        1
    }
}

@MainActor private final class FakePageView: UIView, PageView {
    private var isBlocked: Bool
    private let onBlocked: () -> Void
    private var continuation: CheckedContinuation<Void, Never>?

    /// Whether a blocked move is in progress, until it returns.
    private(set) var isLoading = false

    init(isBlocked: Bool, onBlocked: @escaping () -> Void) {
        self.isBlocked = isBlocked
        self.onBlocked = onBlocked
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Makes the next move wait for `finishLoading()`.
    func blockNextMove() {
        isBlocked = true
    }

    func go(to location: PageLocation, animated: Bool) async {
        guard isBlocked else {
            return
        }
        isLoading = true
        onBlocked()
        await withCheckedContinuation { continuation = $0 }
        isLoading = false
    }

    func finishLoading() {
        isBlocked = false
        continuation?.resume()
        continuation = nil
    }

    func pageDidDisappear() {}
}
