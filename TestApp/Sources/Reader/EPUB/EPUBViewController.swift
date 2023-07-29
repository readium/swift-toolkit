//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import R2Navigator
import R2Shared
import ReadiumAdapterGCDWebServer
import SwiftUI
import UIKit

public extension FontFamily {
    // Example of adding a custom font embedded in the application.
    static let literata: FontFamily = "Literata"
}

class EPUBViewController: ReaderViewController<EPUBNavigatorViewController> {
    private let preferencesStore: AnyUserPreferencesStore<EPUBPreferences>

    init(
        publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        highlights: HighlightRepository,
        initialPreferences: EPUBPreferences,
        preferencesStore: AnyUserPreferencesStore<EPUBPreferences>
    ) throws {
        var templates = HTMLDecorationTemplate.defaultTemplates()
        templates[.pageList] = pageListTemplate()

        let resources = Bundle.main.resourceURL!
        let navigator = try EPUBNavigatorViewController(
            publication: publication,
            initialLocation: locator,
            config: .init(
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
                                file: resources.appendingPathComponent("Fonts/Literata-VariableFont_opsz,wght.ttf"),
                                style: .normal, weight: .variable(200 ... 900)
                            ),
                            CSSFontFace(
                                file: resources.appendingPathComponent("Fonts/Literata-Italic-VariableFont_opsz,wght.ttf"),
                                style: .italic, weight: .variable(200 ... 900)
                            ),
                        ]
                    ).eraseToAnyHTMLFontFamilyDeclaration(),
                ]
            ),
            httpServer: GCDHTTPServer.shared
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

    override var currentBookmark: Bookmark? {
        guard let locator = navigator.currentLocation else {
            return nil
        }

        return Bookmark(bookId: bookId, locator: locator)
    }

    @objc func highlightSelection() {
        if let selection = navigator.currentSelection {
            let highlight = Highlight(bookId: bookId, locator: selection.locator, color: .yellow)
            saveHighlight(highlight)
            navigator.clearSelection()
        }
    }
}

extension EPUBViewController: EPUBNavigatorDelegate {}

extension EPUBViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension Decoration.Style.Id {
    static let pageList: Decoration.Style.Id = "page_list"
}

/**
 * This Decoration Style is used to display the page number labels in the margins, when a book
 * provides a `page-list`. The label is stored in the [DecorationStylePageNumber] itself.
 *
 * See http://kb.daisy.org/publishing/docs/navigation/pagelist.html
 */
private func pageListTemplate(_ tintColor: UIColor = .red) -> HTMLDecorationTemplate {
    let className = "cantook-page-list-mark"

    return HTMLDecorationTemplate(
        layout: .bounds,
        width: .page,
        element: { decoration in
            let config = decoration.style.config as? PageListConfig
            return """
                <div><span class="\(className)" style="background-color: var(--RS__backgroundColor) !important">\(config?.label ?? "")</span></div>
            """
        },
        stylesheet: """
            .\(className) {
                float: left;
                margin-left: 4px;
                padding: 0px 2px 0px 2px;
                border: 1px solid;
                border-radius: 10%;
                box-shadow: rgba(50, 50, 93, 0.25) 0px 2px 5px -1px, rgba(0, 0, 0, 0.3) 0px 1px 3px -1px;
                opacity: 0.8;
            }
        """
    )
}
