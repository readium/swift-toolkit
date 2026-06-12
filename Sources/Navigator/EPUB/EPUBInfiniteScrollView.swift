//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import UIKit

@MainActor
protocol EPUBInfiniteScrollViewDelegate: AnyObject {
    /// Creates the spread view for the given reading-order index.
    func infiniteScrollView(_ view: EPUBInfiniteScrollView, spreadViewAtIndex index: Int) -> EPUBSpreadView?

    /// Called when the loaded views or current index changed.
    func infiniteScrollViewDidUpdateViews(_ view: EPUBInfiniteScrollView)
}

/// Renders EPUB chapters stacked vertically in a single continuous scroll.
///
/// Manages a sliding window of loaded `EPUBSpreadView` instances around the
/// current reading position. Chapters outside the window are evicted; placeholder
/// heights are used until each chapter's WebView reports its actual content height.
@MainActor
final class EPUBInfiniteScrollView: UIScrollView {

    weak var infiniteDelegate: EPUBInfiniteScrollViewDelegate?

    private(set) var chapterCount: Int = 0
    private(set) var currentIndex: Int = 0

    /// Loaded spread views indexed by reading-order position.
    private(set) var loadedViews: [Int: EPUBSpreadView] = [:]

    /// Actual content heights once each chapter's WebView has rendered.
    private var resolvedHeights: [Int: CGFloat] = [:]

    /// KVO tokens observing each chapter's `webView.scrollView.contentSize`.
    private var heightObservations: [Int: NSKeyValueObservation] = [:]

    /// Chapters to preload on each side of the current one.
    private let preloadWindow = 2

    /// Estimate used before a chapter's actual height is known.
    private let placeholderHeight: CGFloat = 1400

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        delegate = self
        showsVerticalScrollIndicator = true
        showsHorizontalScrollIndicator = false
        bounces = true
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .never
        // Prevent inset from conflicting with the outer view controller's layout.
        insertSubview(UIView(frame: .zero), at: 0)
    }

    // MARK: - Public API

    /// Resets the view to display `count` chapters, positioning at `index`.
    func reload(at index: Int, location: PageLocation, count: Int) {
        chapterCount = max(0, count)
        evictAll()
        guard chapterCount > 0 else { return }
        currentIndex = max(0, min(index, chapterCount - 1))
        updateWindow(movingTo: location)
    }

    /// Scrolls (or jumps) to the chapter at `index`, positioning at `location`.
    func goToIndex(_ index: Int, location: PageLocation, options: NavigatorGoOptions) async -> Bool {
        guard 0 ..< chapterCount ~= index else { return false }
        currentIndex = index
        let animated = options.animated && !UIAccessibility.isReduceMotionEnabled
        updateWindow(movingTo: location, animated: animated)
        return true
    }

    /// The spread view for the chapter currently in focus, if loaded.
    var currentView: EPUBSpreadView? { loadedViews[currentIndex] }

    /// Vertical scroll progression within the current chapter (0–1).
    var progressionInCurrentChapter: Double {
        let top = yOffset(for: currentIndex)
        let h = height(for: currentIndex)
        guard h > 0 else { return 0 }
        return min(1, max(0, Double((contentOffset.y - top) / h)))
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard chapterCount > 0 else { return }

        var y: CGFloat = 0
        let w = bounds.width
        for i in 0 ..< chapterCount {
            let h = height(for: i)
            loadedViews[i]?.frame = CGRect(x: 0, y: y, width: w, height: h)
            y += h
        }
        contentSize = CGSize(width: w, height: y)
    }

    // MARK: - Window Management

    private func updateWindow(movingTo location: PageLocation? = nil, animated: Bool = false) {
        guard chapterCount > 0 else { return }

        // Pixel-based window: chapters can be tiny (a 70px separator page) or huge
        // (a 15000px chapter), so a fixed chapter count either wastes memory or
        // lets the user scroll past the preloaded content and hit spinners.
        // Extend the window until it covers `preloadDistance` px in each direction,
        // with `preloadWindow` chapters as the minimum.
        let preloadDistance = max(bounds.height * 3, 2000)

        var lo = max(0, currentIndex - preloadWindow)
        var acc: CGFloat = (lo ..< currentIndex).reduce(0) { $0 + height(for: $1) }
        while lo > 0, acc < preloadDistance {
            lo -= 1
            acc += height(for: lo)
        }

        var hi = min(chapterCount - 1, currentIndex + preloadWindow)
        acc = (currentIndex + 1 ... max(currentIndex + 1, hi)).reduce(0) { $0 + height(for: $1) }
        while hi < chapterCount - 1, acc < preloadDistance {
            hi += 1
            acc += height(for: hi)
        }

        // Evict out-of-window chapters
        for i in loadedViews.keys where !(lo ... hi ~= i) {
            loadedViews[i]?.removeFromSuperview()
            loadedViews.removeValue(forKey: i)
            heightObservations.removeValue(forKey: i)
        }

        // Load new chapters in the window
        for i in lo ... hi where loadedViews[i] == nil {
            guard let view = infiniteDelegate?.infiniteScrollView(self, spreadViewAtIndex: i) else { continue }
            prepareForInfiniteScroll(view)
            loadedViews[i] = view
            addSubview(view)
            observeContentHeight(of: view, at: i)

            // Body can resize after load (CSS injection, font loading) without
            // any contentSize KVO signal — the viewport pins contentSize to the
            // frame height. A ResizeObserver in the page reports those changes.
            view.registerJSMessage(named: "bodyResized") { [weak self, weak view] _ in
                DispatchQueue.main.async {
                    guard let self, let view else { return }
                    self.measureContentHeight(of: view, at: i)
                }
            }
        }

        setNeedsLayout()
        layoutIfNeeded()

        if let location {
            scrollToChapter(currentIndex, location: location, animated: animated)
        }

        infiniteDelegate?.infiniteScrollViewDidUpdateViews(self)
    }

    /// Disables the WebView's own scrolling so the outer scroll handles everything.
    private func prepareForInfiniteScroll(_ view: EPUBSpreadView) {
        view.webView.scrollView.isScrollEnabled = false
        view.webView.scrollView.showsVerticalScrollIndicator = false
        view.webView.scrollView.bounces = false
        view.webView.scrollView.contentInset = .zero
        view.webView.scrollView.contentOffset = .zero
    }

    // MARK: - Height Detection

    private func observeContentHeight(of view: EPUBSpreadView, at index: Int) {
        // `scrollView.contentSize` is circular in this mode: the `<html>` element
        // always stretches to the viewport (= the frame WE set), so contentSize
        // never reports a height smaller than the current frame. We only use the
        // KVO as a "layout changed" signal, then measure the real content extent
        // with JS (`document.body.scrollHeight` is independent of viewport height).
        let obs = view.webView.scrollView.observe(\.contentSize, options: .new) { [weak self, weak view] _, change in
            let signal = change.newValue?.height ?? 0
            // Ignore initial zero/tiny values before content renders
            guard signal > 100 else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, let view else { return }
                self.measureContentHeight(of: view, at: index)
            }
        }
        heightObservations[index] = obs
    }

    private func measureContentHeight(of view: EPUBSpreadView, at index: Int) {
        let js = """
        (function() {
            var b = document.body;
            if (!b) return 0;
            if (!window.__rdrResizeObs__ && window.ResizeObserver) {
                window.__rdrResizeObs__ = new ResizeObserver(function() {
                    try { webkit.messageHandlers.bodyResized.postMessage(b.scrollHeight); } catch (e) {}
                });
                window.__rdrResizeObs__.observe(b);
            }
            var cs = getComputedStyle(b);
            return Math.ceil(b.scrollHeight
                + (parseFloat(cs.marginTop) || 0)
                + (parseFloat(cs.marginBottom) || 0));
        })()
        """
        view.webView.evaluateJavaScript(js) { [weak self, weak view] result, _ in
            // Threshold only filters pre-render readings (body missing → 0).
            // Real chapters can be tiny (e.g., a 70px separator page), so keep it low.
            guard let height = (result as? NSNumber).map({ CGFloat(truncating: $0) }),
                  height > 20 else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.resolvedHeights[index] != height else { return }
                let oldHeight = self.resolvedHeights[index] ?? self.placeholderHeight
                let delta = height - oldHeight
                self.resolvedHeights[index] = height
                view?.frame.size.height = height
                self.setNeedsLayout()
                self.layoutIfNeeded()
                // Compensate so the viewport doesn't jump when a chapter above the
                // current reading position resolves with a different height.
                if index < self.currentIndex && delta != 0 {
                    var offset = self.contentOffset
                    offset.y += delta
                    self.contentOffset = offset
                }

                // Verification pass: a measurement can land mid-reflow (CSS injection,
                // font loading) and the final resize may slip past the ResizeObserver.
                // Re-measure after the layout settles; a stable height is a no-op,
                // so this cannot loop.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak view] in
                    guard let self, let view, self.loadedViews[index] === view else { return }
                    self.measureContentHeight(of: view, at: index)
                }
            }
        }
    }

    private func evictAll() {
        loadedViews.values.forEach { $0.removeFromSuperview() }
        loadedViews.removeAll()
        resolvedHeights.removeAll()
        heightObservations.removeAll()
    }

    // MARK: - Geometry

    private func height(for index: Int) -> CGFloat {
        resolvedHeights[index] ?? placeholderHeight
    }

    /// Returns the Y offset of the top of chapter `index`.
    func yOffset(for index: Int) -> CGFloat {
        (0 ..< index).reduce(0) { $0 + height(for: $1) }
    }

    private func scrollToChapter(_ index: Int, location: PageLocation, animated: Bool) {
        let top = yOffset(for: index)
        let h = height(for: index)
        let targetY: CGFloat

        switch location {
        case .start:
            targetY = top
        case .end:
            targetY = max(0, top + h - bounds.height)
        case .locator(let locator):
            let p = locator.locations.progression ?? 0
            targetY = top + h * CGFloat(p)
        }

        let maxY = max(0, contentSize.height - bounds.height)
        setContentOffset(CGPoint(x: 0, y: min(max(0, targetY), maxY)), animated: animated)
    }

    // MARK: - Current Index Tracking

    private func refreshCurrentIndex() {
        guard chapterCount > 0 else { return }

        let centerY = contentOffset.y + bounds.height / 2
        // Only scan the loaded window — no need to iterate all chapters
        let lo = loadedViews.keys.min() ?? 0
        let hi = loadedViews.keys.max() ?? 0

        var bestIndex = currentIndex
        var bestDist = CGFloat.infinity

        for i in lo ... hi {
            let top = yOffset(for: i)
            let h = height(for: i)
            let dist = abs(centerY - (top + h / 2))
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        guard bestIndex != currentIndex else { return }
        currentIndex = bestIndex
        updateWindow()
    }
}

extension EPUBInfiniteScrollView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        refreshCurrentIndex()
    }
}
