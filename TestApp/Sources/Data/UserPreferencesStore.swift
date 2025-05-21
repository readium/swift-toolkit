//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumNavigator

/// A persistent store for a set of user preferences of type `Preferences`.
protocol UserPreferencesStore {
    associatedtype Preferences: ConfigurablePreferences

    /// Returns the latest preferences of the given book ID.
    func preferences(for bookId: Book.Id) async throws -> Preferences

    /// Sets the latest preferences of the given book ID.
    func savePreferences(_ preferences: Preferences, of bookId: Book.Id) async throws

    /// Observes the preferences of the given book ID.
    func preferencesPublisher(for bookId: Book.Id) -> AnyPublisher<Preferences, Never>
}

/// A `UserPreferencesStore` which splits user preferences and store them in
/// separate stores.
///
/// - publication-specific preferences are stored in the `books` database table
/// - shared (navigator-specific) preferences are stored in the `UserDefaults`.
final class CompositeUserPreferencesStore<Preferences: ConfigurablePreferences>: UserPreferencesStore {
    private let publicationStore: AnyUserPreferencesStore<Preferences>
    private let sharedStore: AnyUserPreferencesStore<Preferences>
    private let publicationFilter: (Preferences) -> Preferences
    private let sharedFilter: (Preferences) -> Preferences

    init<S1: UserPreferencesStore, S2: UserPreferencesStore>(
        publicationStore: S1,
        sharedStore: S2,
        publicationFilter: @escaping (Preferences) -> Preferences,
        sharedFilter: @escaping (Preferences) -> Preferences
    ) where S1.Preferences == Preferences, S2.Preferences == Preferences {
        self.publicationStore = publicationStore.eraseToAnyPreferencesStore()
        self.sharedStore = sharedStore.eraseToAnyPreferencesStore()
        self.publicationFilter = publicationFilter
        self.sharedFilter = sharedFilter
    }

    func preferences(for bookId: Book.Id) async throws -> Preferences {
        try await sharedStore.preferences(for: bookId).merging(publicationStore.preferences(for: bookId))
    }

    func savePreferences(_ preferences: Preferences, of bookId: Book.Id) async throws {
        try await publicationStore.savePreferences(publicationFilter(preferences), of: bookId)
        try await sharedStore.savePreferences(sharedFilter(preferences), of: bookId)
    }

    func preferencesPublisher(for bookId: Book.Id) -> AnyPublisher<Preferences, Never> {
        publicationStore.preferencesPublisher(for: bookId)
            .combineLatest(sharedStore.preferencesPublisher(for: bookId)) { p, s in
                s.merging(p)
            }
            .eraseToAnyPublisher()
    }
}

/// A `UserPreferencesStore` that stores the preferences in the `books`
/// database table.
final class DatabaseUserPreferencesStore<Preferences: ConfigurablePreferences>: UserPreferencesStore {
    private let books: BookRepository

    init(books: BookRepository) {
        self.books = books
    }

    func savePreferences(_ preferences: Preferences, of bookId: Book.Id) async throws {
        try await books.savePreferences(preferences, of: bookId)
    }

    func preferences(for bookId: Book.Id) async throws -> Preferences {
        try await books.get(bookId)?.preferences()
            ?? .empty
    }

    func preferencesPublisher(for bookId: Book.Id) -> AnyPublisher<Preferences, Never> {
        books.observe(bookId)
            .tryMap { book in
                try (book?.preferences() as Preferences?) ?? .empty
            }
            .removeDuplicates()
            .assertNoFailure()
            .eraseToAnyPublisher()
    }
}

/// A `UserPreferencesStore` that stores the preferences in the standard
/// UserDefaults.
final class UserDefaultsUserPreferencesStore<Preferences: ConfigurablePreferences>: UserPreferencesStore {
    private let userDefaults: UserDefaults
    private let key: String = .init(reflecting: Preferences.self)

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    @MainActor
    func preferences(for bookId: Book.Id) async throws -> Preferences {
        guard let data = userDefaults.userPreferences[key] else {
            return .empty
        }
        return try JSONDecoder().decode(Preferences.self, from: data)
    }

    @MainActor
    func savePreferences(_ preferences: Preferences, of bookId: Book.Id) async throws {
        let data = try JSONEncoder().encode(preferences)
        var userPrefs = userDefaults.userPreferences
        userPrefs[key] = data
        userDefaults.userPreferences = userPrefs
    }

    func preferencesPublisher(for bookId: Book.Id) -> AnyPublisher<Preferences, Never> {
        userDefaults.publisher(for: \.userPreferences)
            .tryCompactMap { [self] dict in
                try dict[key].flatMap { try JSONDecoder().decode(Preferences.self, from: $0) }
            }
            .assertNoFailure()
            .eraseToAnyPublisher()
    }
}

private extension UserDefaults {
    @objc dynamic var userPreferences: [String: Data] {
        get { object(forKey: "userPreferences") as? [String: Data] ?? [:] }
        set { set(newValue, forKey: "userPreferences") }
    }
}

extension UserPreferencesStore {
    /// Wraps this `UserPreferencesStore` with a type eraser.
    public func eraseToAnyPreferencesStore() -> AnyUserPreferencesStore<Preferences> {
        AnyUserPreferencesStore(self)
    }
}

/// A type-erasing `UserPreferencesStore` object.
struct AnyUserPreferencesStore<Preferences: ConfigurablePreferences>: UserPreferencesStore {
    private let _preferences: (Book.Id) async throws -> Preferences
    private let _savePreferences: (Preferences, Book.Id) async throws -> Void
    private let _preferencesPublisher: (Book.Id) -> AnyPublisher<Preferences, Never>

    init<P: UserPreferencesStore>(_ preferencesStore: P) where P.Preferences == Preferences {
        _preferences = preferencesStore.preferences
        _savePreferences = preferencesStore.savePreferences
        _preferencesPublisher = preferencesStore.preferencesPublisher
    }

    func preferences(for bookId: Book.Id) async throws -> Preferences {
        try await _preferences(bookId)
    }

    func savePreferences(_ preferences: Preferences, of bookId: Book.Id) async throws {
        try await _savePreferences(preferences, bookId)
    }

    func preferencesPublisher(for bookId: Book.Id) -> AnyPublisher<Preferences, Never> {
        _preferencesPublisher(bookId)
    }
}
