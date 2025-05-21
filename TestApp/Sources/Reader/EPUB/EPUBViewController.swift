//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import ReadiumShared
import SwiftSoup
import SwiftUI
import UIKit
import WebKit

public extension FontFamily {
    // Example of adding a custom font embedded in the application.
    static let literata: FontFamily = "Literata"
}

class EPUBViewController: VisualReaderViewController<EPUBNavigatorViewController> {
    private let preferencesStore: AnyUserPreferencesStore<EPUBPreferences>

    init(
        publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        highlights: HighlightRepository,
        initialPreferences: EPUBPreferences,
        preferencesStore: AnyUserPreferencesStore<EPUBPreferences>,
        httpServer: HTTPServer
    ) throws {
        var templates = HTMLDecorationTemplate.defaultTemplates()
        templates[.pageList] = .pageList

        let resources = FileURL(url: Bundle.main.resourceURL!)!
        let navigator = try EPUBNavigatorViewController(
            publication: publication,
            initialLocation: locator,
            config: EPUBNavigatorViewController.Configuration(
                preferences: initialPreferences,
                editingActions: EditingAction.defaultActions
                    .appending(EditingAction(
                        title: "Highlight",
                        action: #selector(highlightSelection)
                    )),
                decorationTemplates: templates,
                fontFamilyDeclarations: [
                    CSSFontFamilyDeclaration(
                        fontFamily: .literata,
                        fontFaces: [
                            // Literata is a variable font family, so we can provide a font weight range.
                            CSSFontFace(
                                file: resources.appendingPath("Fonts/Literata-VariableFont_opsz,wght.ttf", isDirectory: false),
                                style: .normal, weight: .variable(200 ... 900)
                            ),
                            CSSFontFace(
                                file: resources.appendingPath("Fonts/Literata-Italic-VariableFont_opsz,wght.ttf", isDirectory: false),
                                style: .italic, weight: .variable(200 ... 900)
                            ),
                        ]
                    ).eraseToAnyHTMLFontFamilyDeclaration(),
                ]
            ),
            httpServer: httpServer
        )

        self.preferencesStore = preferencesStore

        super.init(navigator: navigator, publication: publication, bookId: bookId, books: books, bookmarks: bookmarks, highlights: highlights)

        navigator.delegate = self
    }

    override func presentUserPreferences() {
        Task {
            let userPrefs = await UserPreferences(
                model: UserPreferencesViewModel(
                    bookId: bookId,
                    preferences: try! preferencesStore.preferences(for: bookId),
                    configurable: navigator,
                    store: preferencesStore
                ),
                onClose: { [weak self] in
                    self?.dismiss(animated: true)
                }
            )
            let vc = UIHostingController(rootView: userPrefs)
            vc.modalPresentationStyle = .formSheet
            present(vc, animated: true)
        }
    }

    @objc func highlightSelection() {
        if let selection = navigator.currentSelection {
            let highlight = Highlight(bookId: bookId, locator: selection.locator, color: .yellow)
            saveHighlight(highlight)
            navigator.clearSelection()
        }
    }

    // MARK: - Footnotes

    private func presentFootnote(content: String, referrer: String?) -> Bool {
        var title = referrer
        if let t = title {
            title = try? clean(t, .none())
        }
        if !suitableTitle(title) {
            title = nil
        }

        let content = (try? clean(content, .none())) ?? ""
        let page =
            """
            <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                </head>
                <body>
                    \(content)
                </body>
            </html>
            """

        let wk = WKWebView()
        wk.loadHTMLString(page, baseURL: nil)

        let vc = UIViewController()
        vc.view = wk
        vc.navigationItem.title = title
        vc.navigationItem.leftBarButtonItem = BarButtonItem(barButtonSystemItem: .done, actionHandler: { _ in
            vc.dismiss(animated: true, completion: nil)
        })

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true, completion: nil)

        return false
    }

    /// This regex matches any string with at least 2 consecutive letters (not limited to ASCII).
    /// It's used when evaluating whether to display the body of a noteref referrer as the note's title.
    /// I.e. a `*` or `1` would not be used as a title, but `on` or `好書` would.
    private lazy var noterefTitleRegex: NSRegularExpression =
        try! NSRegularExpression(pattern: "[\\p{Ll}\\p{Lu}\\p{Lt}\\p{Lo}]{2}")

    /// Checks to ensure the title is non-nil and contains at least 2 letters.
    private func suitableTitle(_ title: String?) -> Bool {
        guard let title = title else { return false }
        let range = NSRange(location: 0, length: title.utf16.count)
        let match = noterefTitleRegex.firstMatch(in: title, range: range)
        return match != nil
    }
}

extension EPUBViewController: EPUBNavigatorDelegate {
    func navigator(_ navigator: Navigator, shouldNavigateToNoteAt link: ReadiumShared.Link, content: String, referrer: String?) -> Bool {
        presentFootnote(content: content, referrer: referrer)
    }
}

extension EPUBViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
