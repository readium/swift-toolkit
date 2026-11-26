//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumNavigator

/// A persistent store for the `UserSettings` of a reader.
///
/// The settings are split and stored in separate places:
/// - the book-specific settings are stored in the `book` database table,
/// - the shared settings are stored in the `UserDefaults`.
final class UserSettingsStore<Settings: UserSettings> {
    private let books: BookRepository
    private let userDefaults: UserDefaults

    init(books: BookRepository, userDefaults: UserDefaults = .standard) {
        self.books = books
        self.userDefaults = userDefaults
    }

    /// Returns the latest settings of the given book ID.
    func settings(for bookId: Book.Id) async throws -> Settings {
        try await Settings(
            book: bookSettings(for: bookId),
            shared: sharedSettings()
        )
    }

    /// Saves the settings of the given book ID.
    func saveSettings(_ settings: Settings, of bookId: Book.Id) async throws {
        try await books.saveSettings(settings.book, of: bookId)
        try saveSharedSettings(settings.shared)
    }

    /// Observes the settings of the given book ID.
    func settingsPublisher(for bookId: Book.Id) -> AnyPublisher<Settings, Never> {
        let bookSettings = books.observe(bookId)
            .tryMap { book in
                try book?.settings() ?? Settings.BookSettings()
            }

        let sharedSettings = userDefaults.publisher(for: \.userSettings)
            .tryMap { dict in
                try Self.decodeSharedSettings(from: dict) ?? Settings.SharedSettings()
            }

        return bookSettings.combineLatest(sharedSettings) { book, shared in
            Settings(book: book, shared: shared)
        }
        .removeDuplicates()
        .assertNoFailure()
        .eraseToAnyPublisher()
    }

    private func bookSettings(for bookId: Book.Id) async throws -> Settings.BookSettings {
        try await books.get(bookId)?.settings() ?? Settings.BookSettings()
    }

    private func sharedSettings() throws -> Settings.SharedSettings {
        try Self.decodeSharedSettings(from: userDefaults.userSettings) ?? Settings.SharedSettings()
    }

    private func saveSharedSettings(_ settings: Settings.SharedSettings) throws {
        var dict = userDefaults.userSettings
        dict[Settings.storageKey] = try JSONEncoder().encode(settings)
        userDefaults.userSettings = dict
    }

    private static func decodeSharedSettings(from dict: [String: Data]) throws -> Settings.SharedSettings? {
        try dict[Settings.storageKey].map {
            try JSONDecoder().decode(Settings.SharedSettings.self, from: $0)
        }
    }
}

private extension UserDefaults {
    /// Shared settings of each format, by `UserSettings.storageKey`.
    @objc dynamic var userSettings: [String: Data] {
        get { object(forKey: "userSettings") as? [String: Data] ?? [:] }
        set { set(newValue, forKey: "userSettings") }
    }
}
