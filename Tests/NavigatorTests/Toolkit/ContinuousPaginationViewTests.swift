//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

@Suite struct ContinuousPaginationViewTests {
    @MainActor
    @Test("goToIndex end aligns the trailing edge of a tall page")
    func goToIndexEnd() async {
        let delegate = TestPaginationDelegate(pageHeights: [600, 500])
        let paginationView = makePaginationView(
            delegate: delegate,
            frame: CGRect(x: 0, y: 0, width: 320, height: 400)
        )

        paginationView.reloadAtIndex(0, location: .end, pageCount: 2, readingProgression: .ltr)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(abs(paginationView.viewportRect.minY - 200) < 0.5)
    }

    @MainActor
    @Test("forward navigation scrolls by one viewport and updates the first visible page")
    func goForward() async {
        let delegate = TestPaginationDelegate(pageHeights: [100, 320, 320])
        let paginationView = makePaginationView(
            delegate: delegate,
            frame: CGRect(x: 0, y: 0, width: 320, height: 150)
        )

        paginationView.reloadAtIndex(0, location: .start, pageCount: 3, readingProgression: .ltr)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let moved = await paginationView.go(
            to: .right,
            options: NavigatorGoOptions(animated: false),
            readingProgression: .ltr
        )

        #expect(moved)
        #expect(abs(paginationView.viewportRect.minY - 150) < 0.5)
        #expect(paginationView.currentIndex == 1)
    }

    @MainActor
    @Test("reloadAtIndex immediately anchors a far chapter before delayed page loads finish")
    func reloadAtIndexAnchorsFarChapterImmediately() async {
        let delegate = TestPaginationDelegate(
            pageHeights: [100, 100, 100, 100, 100],
            loadDelayNanoseconds: 200_000_000
        )
        let paginationView = makePaginationView(
            delegate: delegate,
            frame: CGRect(x: 0, y: 0, width: 320, height: 100)
        )

        paginationView.reloadAtIndex(4, location: .start, pageCount: 5, readingProgression: .ltr)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(abs(paginationView.viewportRect.minY - 400) < 0.5)
    }

    @MainActor
    @Test("explicit jump cancels stale reload navigation")
    func explicitJumpCancelsStaleReloadNavigation() async {
        let delegate = TestPaginationDelegate(
            pageHeights: [100, 100, 100, 100],
            loadDelayNanoseconds: 200_000_000
        )
        let paginationView = makePaginationView(
            delegate: delegate,
            frame: CGRect(x: 0, y: 0, width: 320, height: 100)
        )

        paginationView.reloadAtIndex(3, location: .start, pageCount: 4, readingProgression: .ltr)
        let didJump = await paginationView.goToIndex(1, location: .start, options: .none)
        try? await Task.sleep(nanoseconds: 250_000_000)

        #expect(didJump)
        #expect(abs(paginationView.viewportRect.minY - 100) < 0.5)
        #expect(paginationView.currentIndex == 1)
    }

    @MainActor
    @Test("locator jumps wait briefly for delayed target offsets")
    func locatorJumpWaitsForDelayedOffset() async {
        let delegate = TestPaginationDelegate(
            pageHeights: [400],
            locatorTargetOffset: 180,
            locatorFailuresBeforeSuccess: 2
        )
        let paginationView = makePaginationView(
            delegate: delegate,
            frame: CGRect(x: 0, y: 0, width: 320, height: 100)
        )

        paginationView.reloadAtIndex(0, location: .start, pageCount: 1, readingProgression: .ltr)
        let locator = Locator(href: "chapter.xhtml", mediaType: .xhtml)
        let didJump = await paginationView.goToIndex(0, location: .locator(locator), options: .none)

        #expect(didJump)
        #expect(abs(paginationView.viewportRect.minY - 180) < 0.5)
    }
}

@MainActor
private func makePaginationView(delegate: TestPaginationDelegate, frame: CGRect) -> ContinuousPaginationView {
    let paginationView = ContinuousPaginationView(
        frame: frame,
        preloadPreviousPositionCount: 1,
        preloadNextPositionCount: 1,
        isScrollEnabled: true
    )
    paginationView.delegate = delegate
    paginationView.frame = frame
    paginationView.layoutIfNeeded()
    return paginationView
}

private final class TestPaginationDelegate: PaginationViewDelegate {
    let pageHeights: [CGFloat]
    let loadDelayNanoseconds: UInt64
    let locatorTargetOffset: CGFloat?
    let locatorFailuresBeforeSuccess: Int

    init(
        pageHeights: [CGFloat],
        loadDelayNanoseconds: UInt64 = 0,
        locatorTargetOffset: CGFloat? = nil,
        locatorFailuresBeforeSuccess: Int = 0
    ) {
        self.pageHeights = pageHeights
        self.loadDelayNanoseconds = loadDelayNanoseconds
        self.locatorTargetOffset = locatorTargetOffset
        self.locatorFailuresBeforeSuccess = locatorFailuresBeforeSuccess
    }

    func paginationView(_ paginationView: any PaginationContainerView, pageViewAtIndex index: Int) -> (UIView & PageView)? {
        TestContinuousPageView(
            height: pageHeights[index],
            loadDelayNanoseconds: loadDelayNanoseconds,
            locatorTargetOffset: locatorTargetOffset,
            locatorFailuresBeforeSuccess: locatorFailuresBeforeSuccess
        )
    }

    func paginationViewDidUpdateViews(_ paginationView: any PaginationContainerView) {}

    func paginationView(_ paginationView: any PaginationContainerView, positionCountAtIndex index: Int) -> Int {
        1
    }
}

private final class TestContinuousPageView: UIView, ContinuousPageView {
    var onPreferredHeightChange: (() -> Void)?
    let height: CGFloat
    let loadDelayNanoseconds: UInt64
    let locatorTargetOffset: CGFloat?
    var remainingLocatorFailures: Int

    init(
        height: CGFloat,
        loadDelayNanoseconds: UInt64 = 0,
        locatorTargetOffset: CGFloat? = nil,
        locatorFailuresBeforeSuccess: Int = 0
    ) {
        self.height = height
        self.loadDelayNanoseconds = loadDelayNanoseconds
        self.locatorTargetOffset = locatorTargetOffset
        remainingLocatorFailures = locatorFailuresBeforeSuccess
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func go(to location: PageLocation, animated: Bool) async {
        guard loadDelayNanoseconds > 0 else {
            return
        }
        try? await Task.sleep(nanoseconds: loadDelayNanoseconds)
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        height
    }

    func targetYOffset(for location: PageLocation, viewportHeight: CGFloat) async -> CGFloat? {
        switch location {
        case .start:
            return 0
        case .end:
            return max(height - viewportHeight, 0)
        case let .locator(locator):
            if let locatorTargetOffset {
                if remainingLocatorFailures > 0 {
                    remainingLocatorFailures -= 1
                    return nil
                }
                return locatorTargetOffset
            }
            let progression = locator.locations.progression ?? 0
            return height * progression
        }
    }
}
