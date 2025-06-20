//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared
import UIKit
import WebKit

/// A view rendering a spread of resources with a reflowable layout.
final class EPUBReflowableSpreadView: EPUBSpreadView {
    private var topConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!

    private static let reflowableScript = loadScript(named: "readium-reflowable")

    required init(
        viewModel: EPUBNavigatorViewModel,
        spread: EPUBSpread,
        scripts: [WKUserScript],
        animatedLoad: Bool
    ) {
        super.init(
            viewModel: viewModel,
            spread: spread,
            scripts: [
                WKUserScript(source: Self.reflowableScript, injectionTime: .atDocumentStart, forMainFrameOnly: false),
            ],
            animatedLoad: animatedLoad
        )
    }

    override func setupWebView() {
        super.setupWebView()

        scrollView.bounces = false
        // Since iOS 16, the default value of alwaysBounceX seems to be true
        // for web views.
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false

        scrollView.isPagingEnabled = !viewModel.scroll

        webView.translatesAutoresizingMaskIntoConstraints = false
        topConstraint = webView.topAnchor.constraint(equalTo: topAnchor)
        topConstraint.priority = .defaultHigh
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            topConstraint, bottomConstraint,
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateContentInset()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContentInset()
    }

    override func loadSpread() {
        guard spread.readingOrderIndices.count == 1 else {
            log(.error, "Only one document at a time can be displayed in a reflowable spread")
            return
        }
        let link = viewModel.readingOrder[spread.leading]
        let url = viewModel.url(to: link)
        webView.load(URLRequest(url: url.url))
    }

    override func applySettings() {
        super.applySettings()

        // Disables paginated mode if scroll is on.
        scrollView.isPagingEnabled = !viewModel.scroll

        updateContentInset()
    }

    private func updateContentInset() {
        if viewModel.scroll {
            topConstraint.constant = 0
            bottomConstraint.constant = 0
            scrollView.contentInset = UIEdgeInsets(top: notchAreaInsets.top, left: 0, bottom: notchAreaInsets.bottom, right: 0)

        } else {
            let contentInset = viewModel.config.contentInset
            var insets = contentInset[traitCollection.verticalSizeClass]
                ?? contentInset[.regular]
                ?? contentInset[.unspecified]
                ?? (top: 0, bottom: 0)

            // Increases the insets by the notch area (eg. iPhone X) to make sure that the content is not overlapped by the screen notch.
            insets.top += notchAreaInsets.top
            insets.bottom += notchAreaInsets.bottom

            topConstraint.constant = insets.top
            bottomConstraint.constant = -insets.bottom
            scrollView.contentInset = .zero
        }
    }

    override func convertPointToNavigatorSpace(_ point: CGPoint) -> CGPoint {
        var point = point
        if viewModel.scroll {
            if scrollView.contentOffset.x < 0 {
                point.x += abs(scrollView.contentOffset.x)
            }
            if scrollView.contentOffset.y < 0 {
                point.y += abs(scrollView.contentOffset.y)
            }
        }
        point.x += webView.frame.minX
        point.y += webView.frame.minY
        return point
    }

    override func convertRectToNavigatorSpace(_ rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = convertPointToNavigatorSpace(rect.origin)
        return rect
    }

    // MARK: - Location and progression

    override func progression(in index: ReadingOrder.Index) -> ClosedRange<Double> {
        guard
            spread.leading == index,
            let progression = progression
        else {
            return 0 ... 0
        }
        return progression
    }

    override func spreadDidLoad() async {
        if
            let link = viewModel.readingOrder.getOrNil(spread.leading),
            let linkJSON = serializeJSONString(link.json)
        {
            await evaluateScript("readium.link = \(linkJSON);")
        }

        // TODO: Better solution for delaying scrolling to pending location
        // This delay is used to wait for the web view pagination to settle and give the CSS and webview time to layout
        // correctly before attempting to scroll to the target progression, otherwise we might end up at the wrong spot.
        // 0.2 seconds seems like a good value for it to work on an iPhone 5s.
        try? await Task.sleep(seconds: 0.2)

        let location = pendingLocation
        await go(to: pendingLocation)

        // The rendering is sometimes very slow. So in case we don't show the first page of the resource, we add
        // a generous delay before showing the spread again.
        let delayed = !location.isStart
        try? await Task.sleep(seconds: delayed ? 0.3 : 0)
    }

    override func go(to direction: EPUBSpreadView.Direction, options: NavigatorGoOptions) async -> Bool {
        guard !viewModel.scroll else {
            return await super.go(to: direction, options: options)
        }

        let factor: CGFloat = {
            switch direction {
            case .left:
                return -1
            case .right:
                return 1
            }
        }()

        let offsetX = scrollView.bounds.width * factor
        var newOffset = scrollView.contentOffset
        newOffset.x += offsetX
        let rounded = round(newOffset.x / offsetX) * offsetX
        newOffset.x = rounded
        guard 0 ..< scrollView.contentSize.width ~= newOffset.x else {
            return false
        }

        scrollView.setContentOffset(newOffset, animated: options.animated)

        // This delay is only used when turning pages in a single resource if
        // the page turn is animated. The delay is roughly the length of the
        // animation.
        // TODO: completion should be implemented using scroll view delegates
        try? await Task.sleep(seconds: 0.3)

        return true
    }

    // Location to scroll to in the resource once the page is loaded.
    private var pendingLocation: PageLocation = .start

    @MainActor
    override func go(to location: PageLocation) async {
        guard isSpreadLoaded else {
            // Delays moving to the location until the document is loaded.
            pendingLocation = location

            await waitGoToCompletion()
            return
        }

        switch location {
        case let .locator(locator):
            await go(to: locator)
        case .start:
            await scroll(toProgression: 0)
        case .end:
            await scroll(toProgression: 1)
        }

        didCompleteGoTo()
    }

    @MainActor
    private func waitGoToCompletion() async {
        await withCheckedContinuation { continuation in
            goToContinuations.append(continuation)
        }
    }

    @MainActor
    private func didCompleteGoTo() {
        for cont in goToContinuations {
            cont.resume()
        }
        goToContinuations.removeAll()
    }

    @MainActor
    private var goToContinuations: [CheckedContinuation<Void, Never>] = []

    @discardableResult
    private func go(to locator: Locator) async -> Bool {
        if !["", "#"].contains(locator.href.string) {
            guard
                let index = viewModel.readingOrder.firstIndexWithHREF(locator.href),
                spread.contains(index: index)
            else {
                log(.warning, "The locator's href is not in the spread")
                return false
            }
        }

        if locator.text.highlight != nil {
            return await scroll(toLocator: locator)
            // TODO: find the first fragment matching a tag ID (need a regex)
        } else if let id = locator.locations.fragments.first, !id.isEmpty {
            return await scroll(toTagID: id)
        } else {
            let progression = locator.locations.progression ?? 0
            return await scroll(toProgression: progression)
        }
    }

    /// Scrolls at given progression (from 0.0 to 1.0)
    @discardableResult
    private func scroll(toProgression progression: Double) async -> Bool {
        guard progression >= 0, progression <= 1 else {
            log(.warning, "Scrolling to invalid progression \(progression)")
            return false
        }

        // Note: The JS layer does not take into account the scroll view's content inset. So it can't be used to reliably scroll to the top or the bottom of the page in scroll mode.
        if viewModel.scroll, !viewModel.verticalText, [0, 1].contains(progression) {
            var contentOffset = scrollView.contentOffset
            contentOffset.y = (progression == 0)
                ? -scrollView.contentInset.top
                : (scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
            scrollView.contentOffset = contentOffset
            return true
        } else {
            let dir = viewModel.readingProgression.rawValue
            await evaluateScript("readium.scrollToPosition(\'\(progression)\', \'\(dir)\')")
            return true
        }
    }

    /// Scrolls at the tag with ID `tagID`.
    @discardableResult
    private func scroll(toTagID tagID: String) async -> Bool {
        let result = await evaluateScript("readium.scrollToId(\'\(tagID)\');")
        switch result {
        case let .success(value):
            return (value as? Bool) ?? false
        case let .failure(error):
            log(.error, error)
            return false
        }
    }

    /// Scrolls at the snippet matching the given text context.
    @discardableResult
    private func scroll(toLocator locator: Locator) async -> Bool {
        guard let json = locator.jsonString else {
            return false
        }
        let result = await evaluateScript("readium.scrollToLocator(\(json));")
        switch result {
        case let .success(value):
            return (value as? Bool) ?? false
        case let .failure(error):
            log(.error, error)
            return false
        }
    }

    // MARK: - Progression

    // Current progression range in the page.
    private var progression: ClosedRange<Double>?
    // To check if a progression change was cancelled or not.
    private var previousProgression: ClosedRange<Double>?

    // Called by the javascript code to notify that scrolling ended.
    private func progressionDidChange(_ body: Any) {
        guard
            isSpreadLoaded,
            let body = body as? [String: Any],
            var firstProgression = body["first"] as? Double,
            var lastProgression = body["last"] as? Double
        else {
            return
        }
        precondition(firstProgression <= lastProgression)
        firstProgression = min(max(firstProgression, 0.0), 1.0)
        lastProgression = min(max(lastProgression, 0.0), 1.0)

        if previousProgression == nil {
            previousProgression = progression
        }
        progression = firstProgression ... lastProgression

        setNeedsNotifyPagesDidChange()
    }

    private func setNeedsNotifyPagesDidChange() {
        // Makes sure we always receive the "ending scroll" event.
        // ie. https://stackoverflow.com/a/1857162/1474476
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(notifyPagesDidChange), object: nil)
        perform(#selector(notifyPagesDidChange), with: nil, afterDelay: 0.3)
    }

    @objc private func notifyPagesDidChange() {
        guard previousProgression != progression else {
            return
        }
        previousProgression = nil
        delegate?.spreadViewPagesDidChange(self)
    }

    // MARK: - Scripts

    override func registerJSMessages() {
        super.registerJSMessages()
        registerJSMessage(named: "progressionChanged") { [weak self] in self?.progressionDidChange($0) }
    }

    // MARK: - WKNavigationDelegate

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)

        // Fixes https://github.com/readium/r2-navigator-swift/issues/141 by disabling the native
        // double-tap gesture.
        // It's an acceptable fix because reflowable resources are not supposed to handle double-tap
        // since there's no zooming capabilities. This doesn't prevent JavaScript to handle
        // double-tap manually.
        webView.removeDoubleTapGestureRecognizer()
    }

    // MARK: - UIScrollViewDelegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        setNeedsNotifyPagesDidChange()
    }
}
