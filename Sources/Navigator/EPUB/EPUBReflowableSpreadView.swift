//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
    private var webViewHeightConstraint: NSLayoutConstraint!
    private var contentInsets: UIEdgeInsets = .zero
    private var measuredDocumentHeight: CGFloat?
    private var documentHeightTask: Task<Void, Never>?

    private static let reflowableScript = loadScript(named: "readium-reflowable")
    private static let continuousScript = """
        (function () {
          if (window.readiumContinuous) {
            return;
          }

          function escapeCssIdentifier(value) {
            if (window.CSS && typeof window.CSS.escape === "function") {
              return window.CSS.escape(value);
            }
            return String(value).replace(/([^a-zA-Z0-9_-])/g, "\\\\$1");
          }

          function cssSelectorForElement(element) {
            if (!element || element.nodeType !== Node.ELEMENT_NODE) {
              return "body";
            }

            if (element.id) {
              return "#" + escapeCssIdentifier(element.id);
            }

            var segments = [];
            var current = element;
            while (current && current.nodeType === Node.ELEMENT_NODE && current !== document.documentElement) {
              var selector = current.nodeName.toLowerCase();
              if (current.id) {
                selector += "#" + escapeCssIdentifier(current.id);
                segments.unshift(selector);
                break;
              }

              var position = 1;
              var sibling = current.previousElementSibling;
              while (sibling) {
                if (sibling.nodeName === current.nodeName) {
                  position += 1;
                }
                sibling = sibling.previousElementSibling;
              }

              selector += ":nth-of-type(" + position + ")";
              segments.unshift(selector);
              current = current.parentElement;
            }

            if (segments.length === 0) {
              return "body";
            }
            return segments.join(" > ");
          }

          function makeRectJSON(rect) {
            return {
              x: rect.x,
              y: rect.y,
              width: rect.width,
              height: rect.height,
              top: rect.top,
              right: rect.right,
              bottom: rect.bottom,
              left: rect.left,
            };
          }

          function rangeForText(root, highlight, before, after) {
            var target = String(highlight || "").trim();
            if (!target) {
              return null;
            }

            var searchRoot = root || document.body;
            var walker = document.createTreeWalker(searchRoot, NodeFilter.SHOW_TEXT, {
              acceptNode: function (node) {
                return node.textContent && node.textContent.trim()
                  ? NodeFilter.FILTER_ACCEPT
                  : NodeFilter.FILTER_REJECT;
              },
            });

            var matches = [];
            var node;
            while ((node = walker.nextNode())) {
              var text = node.textContent || "";
              var index = text.indexOf(target);
              while (index >= 0) {
                matches.push({ node: node, index: index, text: text });
                index = text.indexOf(target, index + 1);
              }
            }

            if (matches.length === 0) {
              return null;
            }

            function score(match) {
              var points = 0;
              if (before && match.text.slice(Math.max(0, match.index - before.length), match.index).indexOf(before) >= 0) {
                points += 1;
              }
              if (after && match.text.slice(match.index + target.length, match.index + target.length + after.length).indexOf(after) >= 0) {
                points += 1;
              }
              return points;
            }

            var best = matches[0];
            var bestScore = score(best);
            for (var i = 1; i < matches.length; i += 1) {
              var candidateScore = score(matches[i]);
              if (candidateScore > bestScore) {
                best = matches[i];
                bestScore = candidateScore;
              }
            }

            var range = document.createRange();
            range.setStart(best.node, best.index);
            range.setEnd(best.node, best.index + target.length);
            return range;
          }

          function rectFromRange(range) {
            if (!range) {
              return null;
            }

            var rects = range.getClientRects();
            if (rects && rects.length > 0) {
              return rects[0];
            }

            return range.getBoundingClientRect();
          }

          function rectFromNode(node) {
            if (!node) {
              return null;
            }

            if (node.nodeType === Node.TEXT_NODE) {
              var textRange = document.createRange();
              textRange.selectNodeContents(node);
              return rectFromRange(textRange);
            }

            if (node.nodeType !== Node.ELEMENT_NODE) {
              return null;
            }

            var rects = node.getClientRects();
            if (rects && rects.length > 0) {
              return rects[0];
            }

            for (var i = 0; i < node.childNodes.length; i += 1) {
              var childRect = rectFromNode(node.childNodes[i]);
              if (childRect) {
                return childRect;
              }
            }

            return node.getBoundingClientRect();
          }

          function fragmentCandidates(fragment) {
            var value = String(fragment || "").trim();
            if (!value) {
              return [];
            }

            if (value.charAt(0) === "#") {
              value = value.slice(1);
            }

            var candidates = [value];
            try {
              var decoded = decodeURIComponent(value);
              if (decoded && candidates.indexOf(decoded) < 0) {
                candidates.push(decoded);
              }
            } catch (_) {}

            return candidates;
          }

          function elementFromFragment(fragment) {
            var candidates = fragmentCandidates(fragment);

            for (var i = 0; i < candidates.length; i += 1) {
              var element = document.getElementById(candidates[i]);
              if (element) {
                return element;
              }
            }

            for (var j = 0; j < candidates.length; j += 1) {
              var namedElements = document.getElementsByName(candidates[j]);
              for (var k = 0; k < namedElements.length; k += 1) {
                return namedElements[k];
              }
            }

            return null;
          }

          function findHeadingByTitle(title) {
            var target = String(title || "").trim();
            if (!target) {
              return null;
            }

            var headings = document.querySelectorAll("h1, h2, h3, h4, h5, h6");
            for (var i = 0; i < headings.length; i += 1) {
              var text = String(headings[i].textContent || "").trim();
              if (text === target) {
                return headings[i];
              }
            }

            for (var j = 0; j < headings.length; j += 1) {
              var partial = String(headings[j].textContent || "").trim();
              if (partial && partial.indexOf(target) >= 0) {
                return headings[j];
              }
            }

            return null;
          }

          function rectFromLocator(locator) {
            try {
              var locations = locator && locator.locations ? locator.locations : {};
              var text = locator && locator.text ? locator.text : {};
              var root = document.body;
              var element = null;

              if (locations.cssSelector) {
                element = document.querySelector(locations.cssSelector);
                if (element) {
                  root = element;
                }
              }

              if (!element && Array.isArray(locations.fragments)) {
                for (var i = 0; i < locations.fragments.length; i += 1) {
                  element = elementFromFragment(locations.fragments[i]);
                  if (element) {
                    break;
                  }
                }
              }

              if (element) {
                return rectFromNode(element);
              }

              if (locator && locator.title) {
                element = findHeadingByTitle(locator.title);
                if (element) {
                  return rectFromNode(element);
                }
              }

              if (text && text.highlight) {
                return rectFromRange(rangeForText(root, text.highlight, text.before, text.after));
              }
            } catch (_) {}

            return null;
          }

          function documentTopOffset() {
            var root = document.body || document.documentElement;
            if (!root) {
              return 0;
            }
            return root.getBoundingClientRect().top;
          }

          function shouldIgnoreElement(element) {
            var style = getComputedStyle(element);
            if (!style) {
              return false;
            }

            if (style.getPropertyValue("display") !== "block") {
              return true;
            }
            return style.getPropertyValue("opacity") === "0";
          }

          function isElementVisibleInRect(element, rect) {
            if (element === document.body || element === document.documentElement) {
              return true;
            }

            var elementRect = element.getBoundingClientRect();
            return (
              elementRect.bottom > rect.top &&
              elementRect.top < rect.bottom &&
              elementRect.right > rect.left &&
              elementRect.left < rect.right
            );
          }

          function findElementInRect(rootElement, rect) {
            for (var i = 0; i < rootElement.children.length; i += 1) {
              var child = rootElement.children[i];
              if (!shouldIgnoreElement(child) && isElementVisibleInRect(child, rect)) {
                return findElementInRect(child, rect);
              }
            }
            return rootElement;
          }

          function contentHeight() {
            var root = document.scrollingElement || document.documentElement || document.body;
            return Math.max(
              root ? root.scrollHeight : 0,
              root ? root.offsetHeight : 0,
              document.documentElement ? document.documentElement.scrollHeight : 0,
              document.documentElement ? document.documentElement.offsetHeight : 0,
              document.body ? document.body.scrollHeight : 0,
              document.body ? document.body.offsetHeight : 0
            );
          }

          window.readiumContinuous = {
            contentHeight: contentHeight,
            locatorRect: function (locator) {
              var rect = rectFromLocator(locator);
              return rect ? makeRectJSON(rect) : null;
            },
            locatorYOffset: function (locator) {
              var rect = rectFromLocator(locator);
              if (!rect) {
                return null;
              }
              return rect.top - documentTopOffset();
            },
            findFirstVisibleLocatorInRect: function (rect) {
              var visibleRect = rect || {
                top: 0,
                left: 0,
                right: window.innerWidth,
                bottom: window.innerHeight,
              };
              var element = findElementInRect(document.body, visibleRect);
              return {
                href: "#",
                type: "application/xhtml+xml",
                locations: {
                  cssSelector: cssSelectorForElement(element),
                },
                text: {
                  highlight: (element.textContent || "").trim(),
                },
              };
            },
            notifyLayoutChange: function () {
              webkit.messageHandlers.continuousContentLayoutChanged.postMessage({});
            },
          };

          window.addEventListener("load", function () {
            var pendingNotification;
            function notify() {
              if (pendingNotification) {
                cancelAnimationFrame(pendingNotification);
              }
              pendingNotification = requestAnimationFrame(function () {
                window.readiumContinuous.notifyLayoutChange();
              });
            }

            notify();
            var observer = new ResizeObserver(notify);
            observer.observe(document.documentElement);
            observer.observe(document.body);
          });
        })();
        """

    private var isContinuousScrolling: Bool {
        scrollMode == .continuous
    }

    required init(
        viewModel: EPUBNavigatorViewModel,
        spread: EPUBSpread,
        scrollMode: ScrollMode,
        scripts: [WKUserScript],
        animatedLoad: Bool
    ) {
        super.init(
            viewModel: viewModel,
            spread: spread,
            scrollMode: scrollMode,
            scripts: [
                WKUserScript(source: Self.reflowableScript, injectionTime: .atDocumentStart, forMainFrameOnly: false),
                WKUserScript(source: Self.continuousScript, injectionTime: .atDocumentStart, forMainFrameOnly: false),
            ],
            animatedLoad: animatedLoad
        )
    }

    override func clear() {
        super.clear()

        documentHeightTask?.cancel()
        documentHeightTask = nil

        // Clean up go to continuations.
        for continuation in goToContinuations {
            continuation.resume()
        }
        goToContinuations.removeAll()

        scrollDidEnd()
    }

    override func setupWebView() {
        super.setupWebView()

        scrollView.bounces = false
        // Since iOS 16, the default value of alwaysBounceX seems to be true
        // for web views.
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false

        scrollView.isPagingEnabled = (scrollMode == .paginated)
        scrollView.isScrollEnabled = !isContinuousScrolling

        webView.translatesAutoresizingMaskIntoConstraints = false
        topConstraint = webView.topAnchor.constraint(equalTo: topAnchor)
        topConstraint.priority = .defaultHigh
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomConstraint.priority = .defaultHigh
        webViewHeightConstraint = webView.heightAnchor.constraint(equalToConstant: 1)
        webViewHeightConstraint.priority = .required
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
        let url = viewModel.url(to: spread.first.link)
        webView.load(URLRequest(url: url.url))
    }

    override func applySettings() {
        super.applySettings()

        scrollView.isPagingEnabled = (scrollMode == .paginated)
        scrollView.isScrollEnabled = !isContinuousScrolling

        updateContentInset()
        if isContinuousScrolling {
            scheduleDocumentHeightUpdate()
        }
    }

    private func updateContentInset() {
        contentInsets = delegate?.spreadViewContentInset(self) ?? .zero

        if isContinuousScrolling {
            topConstraint.constant = contentInsets.top
            bottomConstraint.isActive = false
            webViewHeightConstraint.isActive = true
            webViewHeightConstraint.constant = measuredDocumentHeight ?? estimatedDocumentHeight
            scrollView.contentInset = .zero
        } else if viewModel.scroll {
            topConstraint.constant = 0
            bottomConstraint.isActive = true
            webViewHeightConstraint.isActive = false
            bottomConstraint.constant = 0
            scrollView.contentInset = contentInsets

        } else {
            topConstraint.constant = contentInsets.top
            bottomConstraint.isActive = true
            webViewHeightConstraint.isActive = false
            bottomConstraint.constant = -contentInsets.bottom
            scrollView.contentInset = .zero
        }

        if isContinuousScrolling {
            onPreferredHeightChange?()
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
            spread.first.index == index,
            let progression = progression
        else {
            return 0 ... 0
        }
        return progression
    }

    override func progression(in index: ReadingOrder.Index, visibleRect: CGRect) -> ClosedRange<Double> {
        guard
            isContinuousScrolling,
            spread.first.index == index
        else {
            return progression(in: index)
        }

        let documentHeight = measuredDocumentHeight ?? 0
        guard documentHeight > 0 else {
            return 0 ... 0
        }

        let contentRect = CGRect(
            x: webView.frame.minX,
            y: webView.frame.minY,
            width: webView.frame.width,
            height: documentHeight
        )
        let intersection = visibleRect.intersection(contentRect)
        guard !intersection.isNull, !intersection.isEmpty else {
            return 0 ... 0
        }

        let first = min(max((intersection.minY - contentRect.minY) / documentHeight, 0), 1)
        let last = min(max((intersection.maxY - contentRect.minY) / documentHeight, first), 1)
        return first ... last
    }

    override func spreadDidLoad() async {
        let link = spread.first.link
        if let linkJSON = try? link.jsonString() {
            await evaluateScript("readium.link = \(linkJSON);")
        }

        try? await Task.sleep(seconds: 0.2)

        if isContinuousScrolling {
            await updateDocumentHeight()
            didCompleteGoTo()
            return
        }

        let location = pendingLocation
        await go(to: location.location, animated: location.animated)

        // The rendering is sometimes very slow. So in case we don't show the first page of the resource, we add
        // a generous delay before showing the spread again.
        let delayed = !location.location.isStart
        try? await Task.sleep(seconds: delayed ? 0.3 : 0)
    }

    override func go(to direction: EPUBSpreadView.Direction, options: NavigatorGoOptions) async -> Bool {
        guard !viewModel.scroll, !isContinuousScrolling else {
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

        guard scrollView.bounds.width > 0 else { return false }
        let offsetX = scrollView.bounds.width * factor
        let targetX = round((scrollView.contentOffset.x + offsetX) / offsetX) * offsetX
        guard 0 ..< scrollView.contentSize.width ~= targetX else {
            return false
        }

        // We use JavaScript instead of `UIScrollView.setContentOffset()` to
        // prevent glitches when turning pages without animation.
        // See https://github.com/readium/swift-toolkit/issues/737#issuecomment-4090386881
        //
        // `scrollBy` is used instead of `scrollTo` because RTL content uses
        // negative `window.scrollX` values in WKWebView, whereas UIKit's
        // `contentOffset.x` is always non-negative. A relative displacement
        // (`offsetX`) is coordinate-system agnostic and works for both LTR and
        // RTL.
        let behavior = options.animated ? "smooth" : "instant"
        await evaluateScript("window.scrollBy({ left: \(offsetX), behavior: '\(behavior)' });")

        if options.animated {
            // Waits for the scroll animation to finish.
            await withCheckedContinuation { continuation in
                let request = ScrollAnimationRequest(continuation)
                pendingScrollAnimation?.resume()
                pendingScrollAnimation = request

                // Safety net in case `scrollDidEnd` never fires. The identity
                // check on `request` ensures a stale timeout from a previous
                // request does not resume a newer one.
                Task { @MainActor in
                    try? await Task.sleep(seconds: 0.8)
                    scrollDidEnd(for: request)
                }
            }
        }

        return true
    }

    private struct PendingLocation {
        var location: PageLocation
        var animated: Bool
    }

    /// Location to scroll to in the resource once the page is loaded.
    private var pendingLocation: PendingLocation = .init(location: .start, animated: false)

    override func go(to location: PageLocation, animated: Bool) async {
        guard isSpreadLoaded else {
            // Delays moving to the location until the document is loaded.
            pendingLocation = PendingLocation(location: location, animated: animated)

            await waitGoToCompletion()
            return
        }

        if isContinuousScrolling {
            didCompleteGoTo()
            return
        }

        switch location {
        case let .locator(locator):
            await go(to: locator, animated: animated)
        case .start:
            await scroll(toProgression: 0, animated: animated)
        case .end:
            await scroll(toProgression: 1, animated: animated)
        }

        didCompleteGoTo()
    }

    private func waitGoToCompletion() async {
        await withCheckedContinuation { continuation in
            goToContinuations.append(continuation)
        }
    }

    private func didCompleteGoTo() {
        for cont in goToContinuations {
            cont.resume()
        }
        goToContinuations.removeAll()
    }

    private var estimatedDocumentHeight: CGFloat {
        max(bounds.height - contentInsets.top - contentInsets.bottom, 1)
    }

    override func preferredHeight(for width: CGFloat) -> CGFloat {
        guard isContinuousScrolling else {
            return super.preferredHeight(for: width)
        }
        let documentHeight = measuredDocumentHeight ?? estimatedDocumentHeight
        return max(contentInsets.top + documentHeight + contentInsets.bottom, 1)
    }

    override func targetYOffset(for location: PageLocation, viewportHeight: CGFloat) async -> CGFloat? {
        guard isContinuousScrolling else {
            return await super.targetYOffset(for: location, viewportHeight: viewportHeight)
        }

        let pageHeight = preferredHeight(for: bounds.width)
        let maxOffset = max(pageHeight - viewportHeight, 0)

        switch location {
        case .start:
            return 0
        case .end:
            return maxOffset
        case let .locator(locator):
            for attempt in 0 ..< 6 {
                if let offset = await locatorYOffset(for: locator) {
                    return min(max(contentInsets.top + offset, 0), maxOffset)
                }

                guard attempt < 5 else {
                    break
                }

                await updateDocumentHeight()
                try? await Task.sleep(seconds: 0.05)
            }

            if let progression = locator.locations.progression {
                let documentHeight = measuredDocumentHeight ?? estimatedDocumentHeight
                return min(max(contentInsets.top + documentHeight * progression, 0), maxOffset)
            }

            return 0
        }
    }

    override func firstVisibleElementLocator(in visibleRect: CGRect) async -> Locator? {
        guard isContinuousScrolling else {
            return await super.firstVisibleElementLocator(in: visibleRect)
        }

        let webViewVisibleRect = convert(visibleRect, to: webView)
        guard let rectJSON = jsonString(for: webViewVisibleRect) else {
            return nil
        }

        let result = await evaluateScript("readiumContinuous.findFirstVisibleLocatorInRect(\(rectJSON));")
        do {
            let link = spread.first.link
            guard
                let json = try JSONValue(result.get()),
                let locator = try Locator(json: json)
            else {
                return nil
            }
            return locator.copy(href: link.url(), mediaType: link.mediaType ?? .xhtml)

        } catch {
            log(.error, error)
            return nil
        }
    }

    private func scheduleDocumentHeightUpdate(delay: TimeInterval = 0.05) {
        guard isContinuousScrolling else {
            return
        }

        documentHeightTask?.cancel()
        documentHeightTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            if delay > 0 {
                try? await Task.sleep(seconds: delay)
            }
            await self.updateDocumentHeight()
        }
    }

    private func updateDocumentHeight() async {
        guard isContinuousScrolling else {
            return
        }

        let result = await evaluateScript("readiumContinuous.contentHeight();")
        guard
            case let .success(value) = result,
            let number = value as? NSNumber
        else {
            return
        }

        let height = max(CGFloat(truncating: number), 1)
        guard abs((measuredDocumentHeight ?? 0) - height) > 0.5 else {
            return
        }

        measuredDocumentHeight = height
        webViewHeightConstraint.constant = height
        setNeedsLayout()
        onPreferredHeightChange?()
    }

    private func locatorYOffset(for locator: Locator) async -> CGFloat? {
        guard let locatorJSON = try? locator.jsonString() else {
            return nil
        }

        let result = await evaluateScript("readiumContinuous.locatorYOffset(\(locatorJSON));")
        guard
            case let .success(value) = result,
            let number = value as? NSNumber
        else {
            return nil
        }

        let offset = CGFloat(truncating: number)
        return offset.isFinite ? offset : nil
    }

    private func locatorRect(for locator: Locator) async -> CGRect? {
        guard let locatorJSON = try? locator.jsonString() else {
            return nil
        }

        let result = await evaluateScript("readiumContinuous.locatorRect(\(locatorJSON));")
        guard case let .success(value) = result else {
            return nil
        }

        return CGRect(json: value)
    }

    private func jsonString(for rect: CGRect) -> String? {
        let json: [String: CGFloat] = [
            "top": rect.minY,
            "left": rect.minX,
            "bottom": rect.maxY,
            "right": rect.maxX,
            "width": rect.width,
            "height": rect.height,
            "x": rect.minX,
            "y": rect.minY,
        ]

        guard
            let data = try? JSONSerialization.data(withJSONObject: json),
            let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }

    private var goToContinuations: [CheckedContinuation<Void, Never>] = []

    private var pendingScrollAnimation: ScrollAnimationRequest?

    /// Represents an in-flight animated page turn, waiting for the scroll
    /// animation to settle before completing.
    private class ScrollAnimationRequest {
        private var continuation: CheckedContinuation<Void, Never>?

        init(_ continuation: CheckedContinuation<Void, Never>) {
            self.continuation = continuation
        }

        /// Resumes the continuation. Safe to call multiple times; only the
        /// first call has any effect.
        func resume() {
            continuation?.resume()
            continuation = nil
        }
    }

    private func scrollDidEnd(for request: ScrollAnimationRequest? = nil) {
        guard request == nil || pendingScrollAnimation === request else {
            return
        }
        pendingScrollAnimation?.resume()
        pendingScrollAnimation = nil
    }

    @discardableResult
    private func go(to locator: Locator, animated: Bool) async -> Bool {
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
            return await scroll(toLocator: locator, animated: animated)
            // TODO: find the first fragment matching a tag ID (need a regex)
        } else if let id = locator.locations.fragments.first, !id.isEmpty {
            return await scroll(toTagID: id, animated: animated)
        } else {
            let progression = locator.locations.progression ?? 0
            return await scroll(toProgression: progression, animated: animated)
        }
    }

    /// Scrolls at given progression (from 0.0 to 1.0)
    @discardableResult
    private func scroll(toProgression progression: Double, animated: Bool) async -> Bool {
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
            await evaluateScript("readium.scrollToPosition(\'\(progression)\', \'\(dir)\', \(animated))")
            return true
        }
    }

    /// Scrolls at the tag with ID `tagID`.
    @discardableResult
    private func scroll(toTagID tagID: String, animated: Bool) async -> Bool {
        let result = await evaluateScript("readium.scrollToId(\'\(tagID)\', \(animated));")
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
    private func scroll(toLocator locator: Locator, animated: Bool) async -> Bool {
        guard let json = try? locator.jsonString() else {
            return false
        }
        let result = await evaluateScript("readium.scrollToLocator(\(json), \(animated));")
        switch result {
        case let .success(value):
            return (value as? Bool) ?? false
        case let .failure(error):
            log(.error, error)
            return false
        }
    }

    // MARK: - Progression

    /// Current progression range in the page.
    private var progression: ClosedRange<Double>?
    /// To check if a progression change was cancelled or not.
    private var previousProgression: ClosedRange<Double>?

    /// Called by the javascript code to notify that scrolling ended.
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

        scrollDidEnd()
        delegate?.spreadViewPagesDidChange(self)
    }

    // MARK: - Scripts

    override func registerJSMessages() {
        super.registerJSMessages()
        registerJSMessage(named: "progressionChanged") { [weak self] in self?.progressionDidChange($0) }
        registerJSMessage(named: "continuousContentLayoutChanged") { [weak self] _ in
            self?.scheduleDocumentHeightUpdate(delay: 0)
        }
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
