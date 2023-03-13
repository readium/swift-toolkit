//
//  PDFModule.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 05.03.19.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Navigator
import R2Shared


/// The PDF module is only available on iOS 11 and more, since it relies on PDFKit.
@available(iOS 11.0, *)
final class PDFModule: ReaderFormatModule {

    weak var delegate: ReaderFormatModuleDelegate?
    
    init(delegate: ReaderFormatModuleDelegate?) {
        self.delegate = delegate
    }
    
    func supports(_ publication: Publication) -> Bool {
        return publication.conforms(to: .pdf)
    }
    
    @MainActor
    func makeReaderViewController(for publication: Publication, locator: Locator?, bookId: Book.Id, books: BookRepository, bookmarks: BookmarkRepository, highlights: HighlightRepository) async throws -> UIViewController {
        let preferencesStore = makePreferencesStore(books: books)
        let viewController = try PDFViewController(
            publication: publication,
            locator: locator,
            bookId: bookId,
            books: books,
            bookmarks: bookmarks,
            highlights: highlights,
            initialPreferences: try await preferencesStore.preferences(for: bookId),
            preferencesStore: preferencesStore
        )
        viewController.moduleDelegate = delegate
        return viewController
    }
    
    func makePreferencesStore(books: BookRepository) -> AnyUserPreferencesStore<PDFPreferences> {
        CompositeUserPreferencesStore(
            publicationStore: DatabaseUserPreferencesStore(books: books),
            sharedStore: UserDefaultsUserPreferencesStore(),
            publicationFilter: PDFPreferences.filterPublicationPreferences,
            sharedFilter: PDFPreferences.filterSharedPreferences
        ).eraseToAnyPreferencesStore()
    }
}
