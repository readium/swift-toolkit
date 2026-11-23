//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

@MainActor struct EPUBNavigatorViewModelTests {
    /// A second layout pass of the view, after a first one with the
    /// `initial` insets.
    struct LayoutPass: Sendable, CustomTestStringConvertible {
        let name: String
        let verticalText: Bool
        var safeAreaInsets: UIEdgeInsets = initialInsets
        var reflowableContentInset: UIEdgeInsets = initialInsets
        /// Whether the CSS properties of the layout are updated.
        let commits: Bool

        var testDescription: String {
            name
        }
    }

    /// The vertical text margins come from the top and bottom content inset,
    /// which doesn't include the app's bars, and the horizontal text margins
    /// from the left and right safe area insets.
    @Test("the CSS layout changes only when the insets at the ends of the lines change", arguments: [
        LayoutPass(
            name: "vertical text, the app's bars change the safe area",
            verticalText: true,
            safeAreaInsets: UIEdgeInsets(top: 150, left: 62, bottom: 120, right: 62),
            commits: false
        ),
        LayoutPass(
            name: "vertical text, the top content inset changes",
            verticalText: true,
            reflowableContentInset: UIEdgeInsets(top: 100, left: 62, bottom: 62, right: 62),
            commits: true
        ),
        LayoutPass(
            name: "vertical text, the left and right safe area changes",
            verticalText: true,
            safeAreaInsets: UIEdgeInsets(top: 62, left: 100, bottom: 62, right: 100),
            commits: false
        ),
        LayoutPass(
            name: "horizontal text, the left and right safe area changes",
            verticalText: false,
            safeAreaInsets: UIEdgeInsets(top: 62, left: 100, bottom: 62, right: 100),
            commits: true
        ),
        LayoutPass(
            name: "horizontal text, the content inset changes",
            verticalText: false,
            reflowableContentInset: UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100),
            commits: false
        ),
    ])
    func layoutPass(_ test: LayoutPass) {
        let delegate = ViewModelDelegate()
        let viewModel = makeViewModel(verticalText: test.verticalText)
        viewModel.delegate = delegate

        // A portrait size where the line length isn't limited by the
        // maximal one.
        let size = CGSize(width: 400, height: 420)
        viewModel.viewDidLayout(size: size, safeAreaInsets: initialInsets, reflowableContentInset: initialInsets)
        #expect(delegate.scripts.count == 1)

        viewModel.viewDidLayout(
            size: size,
            safeAreaInsets: test.safeAreaInsets,
            reflowableContentInset: test.reflowableContentInset
        )
        #expect(delegate.scripts.count == (test.commits ? 2 : 1))
    }
}

// MARK: - Helpers

private let initialInsets = UIEdgeInsets(top: 62, left: 62, bottom: 62, right: 62)

@MainActor private func makeViewModel(verticalText: Bool) -> EPUBNavigatorViewModel {
    let publication = Publication(
        manifest: Manifest(
            metadata: Metadata(title: "Reflowable"),
            readingOrder: [Link(href: "chapter.html", mediaType: .xhtml)]
        )
    )
    return EPUBNavigatorViewModel(
        publication: publication,
        readingOrder: publication.readingOrder,
        config: EPUBNavigatorViewController.Configuration(
            preferences: EPUBPreferences(verticalText: verticalText)
        )
    )
}

@MainActor private final class ViewModelDelegate: EPUBNavigatorViewModelDelegate {
    private(set) var scripts: [String] = []

    func epubNavigatorViewModel(_ viewModel: EPUBNavigatorViewModel, runScript script: String, in scope: EPUBScriptScope) {
        scripts.append(script)
    }

    func epubNavigatorViewModelInvalidatePaginationView(_ viewModel: EPUBNavigatorViewModel) {}

    func epubNavigatorViewModel(_ viewModel: EPUBNavigatorViewModel, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError) {}
}
