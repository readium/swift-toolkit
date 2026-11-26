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
    /// `initialInsets`.
    struct LayoutPass: Sendable, CustomTestStringConvertible {
        let name: String
        let reflowableContentInset: UIEdgeInsets
        /// Whether the CSS properties of the layout are updated.
        let commits: Bool

        var testDescription: String {
            name
        }
    }

    /// The margins of horizontal text come from the left and right content
    /// insets.
    @Test("the CSS layout changes only when the insets at the ends of the lines change", arguments: [
        LayoutPass(
            name: "the right inset changes",
            reflowableContentInset: UIEdgeInsets(top: 62, left: 62, bottom: 62, right: 100),
            commits: true
        ),
        LayoutPass(
            name: "the top and bottom insets change",
            reflowableContentInset: UIEdgeInsets(top: 100, left: 62, bottom: 100, right: 62),
            commits: false
        ),
    ])
    func layoutPass(_ test: LayoutPass) {
        let delegate = ViewModelDelegate()
        let viewModel = makeViewModel()
        viewModel.delegate = delegate

        // A portrait size where the line length isn't limited by the
        // maximal one.
        let size = CGSize(width: 400, height: 420)
        viewModel.viewDidLayout(
            size: size,
            reflowableContentInset: initialInsets,
            hingeWidth: nil
        )
        #expect(delegate.scripts.count == 1)

        viewModel.viewDidLayout(
            size: size,
            reflowableContentInset: test.reflowableContentInset,
            hingeWidth: nil
        )
        #expect(delegate.scripts.count == (test.commits ? 2 : 1))
    }

    /// An iPad Air 13-inch in landscape gets two columns only up to a 100%
    /// font size, and the lines are limited by the maximal line length
    /// multiplied by the font size. A font size of 0 is laid out like 100%.
    @Test("the layout follows the font size", arguments: [
        (0.0, LayoutResolver.Layout(colCount: 2, lineLength: 623)),
        (0.8, LayoutResolver.Layout(colCount: 2, lineLength: 712 * 0.8)),
        (1.0, LayoutResolver.Layout(colCount: 2, lineLength: 623)),
        (1.2, LayoutResolver.Layout(colCount: 1, lineLength: 712 * 1.2)),
    ])
    func layoutFollowsFontSize(fontSize: Double, expected: LayoutResolver.Layout) {
        let viewModel = makeViewModel(preferences: EPUBPreferences(fontSize: fontSize))
        viewModel.viewDidLayout(
            size: CGSize(width: 1366, height: 1024),
            reflowableContentInset: .zero,
            hingeWidth: nil
        )
        #expect(viewModel.resolvedLayout == expected)
    }

    @Test("the layout is resolved again when the font size changes")
    func layoutUpdatedWithFontSize() {
        let delegate = ViewModelDelegate()
        let viewModel = makeViewModel(preferences: EPUBPreferences())
        viewModel.delegate = delegate
        viewModel.viewDidLayout(
            size: CGSize(width: 1366, height: 1024),
            reflowableContentInset: .zero,
            hingeWidth: nil
        )
        #expect(viewModel.resolvedLayout?.colCount == 2)

        viewModel.submitPreferences(EPUBPreferences(fontSize: 1.2))
        #expect(viewModel.resolvedLayout?.colCount == 1)
        #expect(delegate.scripts.count == 2)
        #expect(delegate.scripts.last?.contains(#""--USER__colCount":"1""#) == true)
    }

    /// Right after a foldable device is unfolded, the hinge is only reported
    /// from the second layout pass, with the same size and insets.
    @Test("the layout is resolved again when the hinge appears")
    func layoutUpdatedWithHinge() {
        let delegate = ViewModelDelegate()
        let viewModel = makeViewModel(preferences: EPUBPreferences())
        viewModel.delegate = delegate
        let size = CGSize(width: 951, height: 669)

        viewModel.viewDidLayout(size: size, reflowableContentInset: .zero, hingeWidth: nil)
        #expect(viewModel.resolvedLayout?.colCount == 1)

        viewModel.viewDidLayout(size: size, reflowableContentInset: .zero, hingeWidth: 40)
        #expect(viewModel.resolvedLayout == LayoutResolver.Layout(colCount: 2, lineLength: 415.5))
        #expect(delegate.scripts.count == 2)
        #expect(delegate.scripts.last?.contains(#""--USER__colCount":"2""#) == true)
    }
}

// MARK: - Helpers

private let initialInsets = UIEdgeInsets(top: 62, left: 62, bottom: 62, right: 62)

@MainActor private func makeViewModel(preferences: EPUBPreferences = EPUBPreferences()) -> EPUBNavigatorViewModel {
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
            preferences: preferences
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
