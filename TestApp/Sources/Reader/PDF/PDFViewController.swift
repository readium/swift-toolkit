//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
import SwiftUI
import UIKit

final class PDFViewController: VisualReaderViewController<PDFNavigatorViewController> {
    private let settingsStore: UserSettingsStore<PDFUserSettings>

    init(
        publication: Publication,
        locator: Locator?,
        bookId: Book.Id,
        books: BookRepository,
        bookmarks: BookmarkRepository,
        highlights: HighlightRepository,
        initialPreferences: PDFPreferences,
        settingsStore: UserSettingsStore<PDFUserSettings>
    ) throws {
        self.settingsStore = settingsStore

        let navigator = try PDFNavigatorViewController(
            publication: publication,
            initialLocation: locator,
            config: PDFNavigatorViewController.Configuration(
                preferences: initialPreferences,
                defaults: PDFUserSettings.defaults
            )
        )

        super.init(navigator: navigator, publication: publication, bookId: bookId, books: books, bookmarks: bookmarks, highlights: highlights)

        navigator.delegate = self
    }

    override func presentUserPreferences() {
        Task {
            let userPrefs = await UserPreferences(
                model: UserPreferencesViewModel(
                    bookId: bookId,
                    publication: publication,
                    settings: try! settingsStore.settings(for: bookId),
                    store: settingsStore,
                    submit: { [navigator] in navigator.submitPreferences($0) }
                ),
                onClose: { [weak self = self] in
                    self?.dismiss(animated: true)
                }
            )
            presentUserPreferencesSheet(userPrefs)
        }
    }
}

extension PDFViewController: PDFNavigatorDelegate {}
