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

    /// Layout expected with the given preferences.
    struct ResolvedLayout: Sendable, CustomTestStringConvertible {
        let name: String
        let preferences: EPUBPreferences
        let colCount: Int
        let lineLength: Double

        var testDescription: String {
            name
        }

        /// Checks the layout resolved in a view of `size`, with a tolerance
        /// for the line length.
        @MainActor func expectLayout(in size: CGSize) throws {
            let viewModel = makeViewModel(preferences: preferences)
            viewModel.viewDidLayout(size: size, reflowableContentInset: .zero, hingeWidth: nil)
            let layout = try #require(viewModel.resolvedLayout)
            #expect(layout.colCount == colCount)
            #expect(abs(layout.lineLength - lineLength) < 0.001)
        }
    }

    /// An iPad Air 13-inch in landscape gets two columns only up to a 100%
    /// font size, and the lines are limited by the maximal line length of 80
    /// characters, whose width follows the font size. A font size of 0 is
    /// laid out like 100%.
    @Test("the layout follows the font size", arguments: [
        ResolvedLayout(name: "0%", preferences: EPUBPreferences(fontSize: 0), colCount: 2, lineLength: 623),
        ResolvedLayout(name: "80%", preferences: EPUBPreferences(fontSize: 0.8), colCount: 2, lineLength: 80 * iowanWidth * 0.8),
        ResolvedLayout(name: "100%", preferences: EPUBPreferences(fontSize: 1.0), colCount: 2, lineLength: 623),
        ResolvedLayout(name: "120%", preferences: EPUBPreferences(fontSize: 1.2), colCount: 1, lineLength: 80 * iowanWidth * 1.2),
    ])
    func layoutFollowsFontSize(_ example: ResolvedLayout) throws {
        try example.expectLayout(in: CGSize(width: 1366, height: 1024))
    }

    /// Two columns requested on an iPad Air 11-inch in portrait, with
    /// 350pt lines.
    @Test("the line lengths are counted in characters, and 0 and .infinity remove the limits", arguments: [
        // Below the default minimum of 40 characters (355.69pt), one column
        // limited by the default maximum of 80 characters.
        ResolvedLayout(name: "the default limits", preferences: EPUBPreferences(columnCount: 2), colCount: 1, lineLength: 80 * iowanWidth),
        ResolvedLayout(name: "a lower minimum", preferences: EPUBPreferences(columnCount: 2, minimalLineLength: 39), colCount: 2, lineLength: 350),
        ResolvedLayout(name: "no minimum", preferences: EPUBPreferences(columnCount: 2, minimalLineLength: 0), colCount: 2, lineLength: 350),
        ResolvedLayout(name: "no maximum", preferences: EPUBPreferences(columnCount: 2, maximalLineLength: .infinity), colCount: 1, lineLength: 760),
    ])
    func lineLengthsInCharacters(_ example: ResolvedLayout) throws {
        try example.expectLayout(in: CGSize(width: 820, height: 1180))
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

/// Width of a `0` in Iowan Old Style at 16pt, the width of a character at a
/// 100% font size: 65 of them measure 578pt.
private let iowanWidth = 578.0 / 65

@MainActor private func makeViewModel(preferences: EPUBPreferences = EPUBPreferences()) -> EPUBNavigatorViewModel {
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
