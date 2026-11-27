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
        viewModel.viewDidLayout(
            size: size,
            safeAreaInsets: initialInsets,
            reflowableContentInset: initialInsets,
            hingeWidth: nil
        )
        #expect(delegate.scripts.count == 1)

        viewModel.viewDidLayout(
            size: size,
            safeAreaInsets: test.safeAreaInsets,
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
            safeAreaInsets: .zero,
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
            safeAreaInsets: .zero,
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

        viewModel.viewDidLayout(size: size, safeAreaInsets: .zero, reflowableContentInset: .zero, hingeWidth: nil)
        #expect(viewModel.resolvedLayout?.colCount == 1)

        viewModel.viewDidLayout(size: size, safeAreaInsets: .zero, reflowableContentInset: .zero, hingeWidth: 40)
        #expect(viewModel.resolvedLayout == LayoutResolver.Layout(colCount: 2, lineLength: 415.5))
        #expect(delegate.scripts.count == 2)
        #expect(delegate.scripts.last?.contains(#""--USER__colCount":"2""#) == true)
    }

    @Suite("Settings resolved for given preferences") @MainActor struct SettingsForPreferences {
        @Test("use the defaults of the configuration")
        func usesDefaults() {
            let viewModel = makeViewModel(config: .init(defaults: EPUBDefaults(fontSize: 1.5, scroll: true)))
            let settings = viewModel.settings(for: EPUBPreferences(fontSize: 2))
            #expect(settings.fontSize == 2)
            #expect(settings.scroll)
        }

        /// The publication is reflowable, but its resources have bitmap
        /// alternates rendered as fixed-layout with the `.image` variant.
        @Test("use the layouts of the reading order rendered by the navigator")
        func usesRenderedReadingOrder() {
            var page = Link(href: "page.xhtml", mediaType: .xhtml)
            page.alternates = [Link(href: "page.jpg", mediaType: .jpeg)]
            let publication = Publication(manifest: Manifest(metadata: Metadata(title: "Test"), readingOrder: [page]))

            let authored = makeViewModel(publication: publication, config: .init(preferredResourceVariant: .default))
                .settings(for: EPUBPreferences())
            #expect(authored.isApplicable(\.fontSize))
            #expect(!authored.isApplicable(\.fit))

            let images = makeViewModel(publication: publication, config: .init(preferredResourceVariant: .image))
                .settings(for: EPUBPreferences())
            #expect(!images.isApplicable(\.fontSize))
            #expect(images.isApplicable(\.fit))
        }

        @Test("are applied unchanged by submitting the same preferences")
        func appliedBySubmitting() {
            let viewModel = makeViewModel(config: .init(defaults: EPUBDefaults(columnCount: 2, pageMargins: 1.5)))
            let preferences = EPUBPreferences(fontSize: 1.4, language: Language("ja"), textAlign: .justify)
            let resolved = viewModel.settings(for: preferences)
            #expect(viewModel.settings != resolved)

            viewModel.submitPreferences(preferences)
            #expect(viewModel.settings == resolved)
        }
    }
}

// MARK: - Helpers

private let initialInsets = UIEdgeInsets(top: 62, left: 62, bottom: 62, right: 62)

@MainActor private func makeViewModel(verticalText: Bool) -> EPUBNavigatorViewModel {
    makeViewModel(preferences: EPUBPreferences(verticalText: verticalText))
}

@MainActor private func makeViewModel(preferences: EPUBPreferences) -> EPUBNavigatorViewModel {
    makeViewModel(config: EPUBNavigatorViewController.Configuration(preferences: preferences))
}

@MainActor private func makeViewModel(
    publication: Publication = Publication(
        manifest: Manifest(
            metadata: Metadata(title: "Reflowable"),
            readingOrder: [Link(href: "chapter.html", mediaType: .xhtml)]
        )
    ),
    config: EPUBNavigatorViewController.Configuration
) -> EPUBNavigatorViewModel {
    EPUBNavigatorViewModel(
        publication: publication,
        readingOrder: publication.readingOrder,
        config: config
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
