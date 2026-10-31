//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import UIKit
import WebKit
import XCTest

@MainActor
final class ContentJavaScriptTests: XCTestCase {
    func testPublicationScriptsDisabled() async throws {
        try await checkScripts(configuration: .init(allowsContentJavaScript: false), expectedText: "Original passage")
    }

    func testPublicationScriptsEnabled() async throws {
        try await checkScripts(configuration: .init(allowsContentJavaScript: true), expectedText: "BOOK SCRIPT RAN")
    }

    func testPublicationScriptsEnabledByDefault() async throws {
        try await checkScripts(configuration: .init(), expectedText: "BOOK SCRIPT RAN")
    }

    private func checkScripts(
        configuration: EPUBNavigatorViewController.Configuration,
        expectedText: String
    ) async throws {
        let link = Link(href: "chapter.xhtml", mediaType: .xhtml)
        let publication = Publication(
            manifest: Manifest(metadata: Metadata(title: "Script policy"), readingOrder: [link]),
            container: SingleResourceContainer(resource: DataResource(string: Self.chapter), at: link.url())
        )
        let viewModel = EPUBNavigatorViewModel(
            publication: publication, readingOrder: publication.readingOrder, config: configuration
        )
        let spread = EPUBReflowableSpreadView(
            viewModel: viewModel,
            spread: .single(EPUBSingleSpread(resource: EPUBSpreadResource(index: 0, link: link))),
            scripts: [], animatedLoad: false
        )
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        spread.frame = controller.view.bounds
        controller.view.addSubview(spread)
        defer {
            spread.removeFromSuperview()
            window.isHidden = true
        }
        let loaded = expectation(description: "Readium spread loaded through trusted user script")
        spread.whenSpreadLoaded { loaded.fulfill() }
        await fulfillment(of: [loaded], timeout: 60)

        let text = try await spread.webView.evaluateJavaScript("document.getElementById('message').textContent")
        XCTAssertEqual(text as? String, expectedText)
        let style = try await spread.webView.evaluateJavaScript("""
        readium.setCSSProperties({'--script-policy-test': 'active'});
        document.documentElement.style.getPropertyValue('--script-policy-test');
        """)
        XCTAssertEqual(style as? String, "active", "Trusted Readium injection and host evaluation remain available")
    }

    private static let chapter = """
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head><title>Script policy</title></head>
    <body>
    <p id="message">Original passage</p>
    <script>document.getElementById('message').textContent = 'BOOK SCRIPT RAN';</script>
    </body>
    </html>
    """
}
