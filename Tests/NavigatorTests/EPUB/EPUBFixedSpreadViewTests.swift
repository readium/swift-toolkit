//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

@MainActor struct EPUBFixedSpreadViewTests {
    /// A loaded fixed-layout spread reports its pages right away, so the
    /// navigator doesn't wait for the preloaded spreads to report the
    /// location.
    @Test func reportsItsPagesOnceLoaded() async {
        let publication = Publication(
            manifest: Manifest(
                metadata: Metadata(title: "FXL", layout: .fixed),
                readingOrder: [Link(href: "page1.html"), Link(href: "page2.html")]
            )
        )
        let viewModel = EPUBNavigatorViewModel(
            publication: publication,
            readingOrder: publication.readingOrder,
            config: EPUBNavigatorViewController.Configuration()
        )
        let spread = EPUBSpread.makeSpreads(
            for: publication,
            readingOrder: publication.readingOrder,
            readingProgression: .ltr,
            spread: false
        )[0]
        let view = EPUBFixedSpreadView(viewModel: viewModel, spread: spread, scripts: [], animatedLoad: false)
        let delegate = SpreadViewDelegate()
        view.delegate = delegate

        await view.spreadDidLoad()

        #expect(delegate.pagesDidChangeCount == 1)
        view.clear()
    }
}

@MainActor private final class SpreadViewDelegate: EPUBSpreadViewDelegate {
    private(set) var pagesDidChangeCount = 0

    func spreadViewPagesDidChange(_ spreadView: EPUBSpreadView) {
        pagesDidChangeCount += 1
    }

    func spreadViewContentInset(_ spreadView: EPUBSpreadView) -> UIEdgeInsets {
        .zero
    }

    func spreadViewDidLoad(_ spreadView: EPUBSpreadView) async {}
    func spreadView(_ spreadView: EPUBSpreadView, didTapOnExternalURL url: URL) {}
    func spreadView(_ spreadView: EPUBSpreadView, didTapOnInternalLink href: String, clickEvent: ClickEvent?) {}
    func spreadView(_ spreadView: EPUBSpreadView, didActivateDecoration id: Decoration.Id, inGroup group: DecorationGroup, frame: CGRect?, point: CGPoint?) {}
    func spreadView(_ spreadView: EPUBSpreadView, selectionDidChange text: Locator.Text?, frame: CGRect) {}
    func spreadView(_ spreadView: EPUBSpreadView, didReceive event: PointerEvent) {}
    func spreadView(_ spreadView: EPUBSpreadView, didReceive event: KeyEvent) {}
    func spreadViewDidTerminate() {}
}
