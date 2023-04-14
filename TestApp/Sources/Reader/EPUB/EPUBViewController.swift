//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit
import R2Shared
import R2Navigator
import ReadiumAdapterGCDWebServer
import SwiftUI

extension FontFamily {
    // Example of adding a custom font embedded in the application.
    public static let literata: FontFamily = "Literata"
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
                fontFamilyDeclarations: [
                    CSSFontFamilyDeclaration(
                        fontFamily: .literata,
                        fontFaces: [
                            // Literata is a variable font family, so we can provide a font weight range.
                            CSSFontFace(
                                file: resources.appendingPathComponent("Fonts/Literata-VariableFont_opsz,wght.ttf"),
                                style: .normal, weight: .variable(200...900)
                            ),
                            CSSFontFace(
                                file: resources.appendingPathComponent("Fonts/Literata-Italic-VariableFont_opsz,wght.ttf"),
                                style: .italic, weight: .variable(200...900)
                            )
                        ]
                    ).eraseToAnyHTMLFontFamilyDeclaration()
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
            let userPrefs = UserPreferences(
                model: UserPreferencesViewModel(
                    bookId: bookId,
                    preferences: try! await preferencesStore.preferences(for: bookId),
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

extension EPUBViewController: EPUBNavigatorDelegate {
    
}

extension EPUBViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}
