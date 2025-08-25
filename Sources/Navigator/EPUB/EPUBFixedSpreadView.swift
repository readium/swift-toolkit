//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit
import WebKit

/// A view rendering a spread of resources with a fixed layout.
final class EPUBFixedSpreadView: EPUBSpreadView {
    /// Whether the host wrapper page is loaded or not. The wrapper page contains the iframe that will display the resource.
    private var isWrapperLoaded = false
    /// URL to load in the iframe once the wrapper page is loaded.
    private var urlToLoad: URL?

    private static let fixedScript = loadScript(named: "readium-fixed")

    required init(
        viewModel: EPUBNavigatorViewModel,
        spread: EPUBSpread,
        scripts: [WKUserScript],
        animatedLoad: Bool
    ) {
        var scripts = scripts
        scripts.append(WKUserScript(source: Self.fixedScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        super.init(viewModel: viewModel, spread: spread, scripts: scripts, animatedLoad: animatedLoad)
    }

    override func setupWebView() {
        super.setupWebView()

        // Used to center the web view's content. Since the web view is centered by changing its frame directly, unclipping its bounds allows to see the overflowing content when zooming in.
        webView.clipsToBounds = false
        scrollView.clipsToBounds = false
        clipsToBounds = true

        // Required to have the page centered when zooming out. It also feels more natural.
        scrollView.bounces = true

        // Makes sure that we can see the superview's background color behind the iframe.
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        scrollView.backgroundColor = UIColor.clear

        // Loads the wrapper page into the web view.
        let spreadFile = "fxl-spread-\(spread.spread ? "two" : "one")"
        if
            let wrapperPageURL = Bundle.module.url(forResource: spreadFile, withExtension: "html", subdirectory: "Assets"),
            var wrapperPage = try? String(contentsOf: wrapperPageURL, encoding: .utf8)
        {
            wrapperPage = wrapperPage.replacingOccurrences(
                of: "{{ASSETS_URL}}",
                with: viewModel.assetsURL.string
            )

            // The publication's base URL is used to make sure we can access the resources through the iframe with JavaScript.
            webView.loadHTMLString(wrapperPage, baseURL: viewModel.publicationBaseURL.url)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSpread()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        layoutSpread()
    }

    /// Layouts the resource to fit its content in the bounds.
    private func layoutSpread() {
        guard isWrapperLoaded else {
            return
        }

        // Insets the bounds by the notch area (eg. iPhone X) to make sure that
        // the content is not overlapped by the screen notch.
        var insets = notchAreaInsets

        // Use the same insets on the left and right side (the largest one) to
        // keep the pages centered on the screen even if the notches are not
        // symmetrical.
        let horizontalInsets = max(insets.left, insets.right)
        insets.left = horizontalInsets
        insets.right = horizontalInsets

        let viewportSize = bounds.inset(by: insets).size

        webView.evaluateJavaScript("""
            spread.setViewport(
                {'width': \(Int(viewportSize.width)), 'height': \(Int(viewportSize.height))},
                {'top': \(Int(insets.top)), 'left': \(Int(insets.left)), 'bottom': \(Int(insets.bottom)), 'right': \(Int(insets.right))}
            );
        """)
    }

    override func loadSpread() {
        guard isWrapperLoaded else {
            return
        }
        // We call this directly on the web view on purpose, because this needs
        // to be executed before the spread is loaded.
        let spreadJSON = spread.jsonString(
            forBaseURL: viewModel.publicationBaseURL,
            readingOrder: viewModel.readingOrder
        )
        webView.evaluateJavaScript("spread.load(\(spreadJSON));")
    }

    override func spreadDidLoad() async {
        for continuation in goToContinuations {
            continuation.resume()
        }
        goToContinuations.removeAll()
    }

    override func evaluateScript(_ script: String, inHREF href: AnyURL? = nil) async -> Result<Any, any Error> {
        let href = href?.string ?? ""
        let script = "spread.eval('\(href)', `\(script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`);"
        return await super.evaluateScript(script)
    }

    override func convertPointToNavigatorSpace(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * scrollView.zoomScale - scrollView.contentOffset.x + webView.frame.minX,
            y: point.y * scrollView.zoomScale - scrollView.contentOffset.y + webView.frame.minY
        )
    }

    override func convertRectToNavigatorSpace(_ rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = convertPointToNavigatorSpace(rect.origin)
        rect.size = CGSize(
            width: rect.width * scrollView.zoomScale,
            height: rect.height * scrollView.zoomScale
        )
        return rect
    }

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)

        if !isWrapperLoaded {
            isWrapperLoaded = true
            layoutSpread()
            loadSpread()
        }
    }

    // MARK: - Location and progression

    private var goToContinuations: [CheckedContinuation<Void, Never>] = []

    override func go(to location: PageLocation) async {
        // Fixed layout resources are always fully visible so we don't use the
        // location.

        if isSpreadLoaded {
            return
        } else {
            await withCheckedContinuation { continuation in
                goToContinuations.append(continuation)
            }
        }
    }
}
