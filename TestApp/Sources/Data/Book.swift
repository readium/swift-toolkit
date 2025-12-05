//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import GRDB
import ReadiumShared

struct Book: Codable {
    struct Id: EntityId { let rawValue: Int64 }

    let id: Id?
    /// Canonical identifier for the publication, extracted from its metadata.
    var identifier: String?
    /// Title of the publication, extracted from its metadata.
    var title: String
    /// Authors of the publication, separated by commas.
    var authors: String?
    /// Media type associated to the publication.
    var type: String
    /// Location of the packaged publication or a manifest. It can be a relative
    /// path to the Documents/ folder, or an absolute URL.
    var url: String
    /// Location of the cover.
    var coverPath: String?
    /// Last read location in the publication.
    var locator: Locator? {
        didSet { progression = locator?.locations.totalProgression ?? 0 }
    }

    /// Current progression in the publication, extracted from the locator.
    var progression: Double
    /// Date of creation.
    var created: Date
    /// JSON of user preferences specific to this publication (e.g. language,
    /// reading progression, spreads).
    var preferencesJSON: String?

    var mediaType: MediaType { MediaType(type) ?? .binary }

    init(
        id: Id? = nil,
        identifier: String? = nil,
        title: String,
        authors: String? = nil,
        type: String,
        url: AnyURL,
        coverPath: String? = nil,
        locator: Locator? = nil,
        created: Date = Date(),
        preferencesJSON: String? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.title = title
        self.authors = authors
        self.type = type
        self.url = url.string
        self.coverPath = coverPath
        self.locator = locator
        progression = locator?.locations.totalProgression ?? 0
        self.created = created
        self.preferencesJSON = preferencesJSON
    }

    var cover: FileURL? {
        coverPath.map { Paths.covers.appendingPath($0, isDirectory: false) }
    }

    func preferences<P: Decodable>() throws -> P? {
        guard let data = preferencesJSON.flatMap({ $0.data(using: .utf8) }) else {
            return nil
        }
        return try JSONDecoder().decode(P.self, from: data)
    }

    mutating func setPreferences<P: Encodable>(_ preferences: P) throws {
        let data = try JSONEncoder().encode(preferences)
        preferencesJSON = String(data: data, encoding: .utf8)
    }
}

extension Book: TableRecord, FetchableRecord, PersistableRecord {
    enum Columns: String, ColumnExpression {
        case id, identifier, title, type, url, coverPath, locator, progression, created, preferencesJSON
    }
}

final class BookRepository {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func get(_ id: Book.Id) async throws -> Book? {
        try await db.read { db in
            try Book.fetchOne(db, key: id)
        }
    }

    func observe(_ id: Book.Id) -> AnyPublisher<Book?, Error> {
        db.observe { db in
            try Book.fetchOne(db, key: id)
        }
    }

    func all() -> AnyPublisher<[Book], Error> {
        db.observe { db in
            try Book.order(Book.Columns.created).fetchAll(db)
        }
    }

    @discardableResult
    func add(_ book: Book) async throws -> Book.Id {
        try await db.write { db in
            try book.insert(db)
            return Book.Id(rawValue: db.lastInsertedRowID)
        }
    }

    func remove(_ id: Book.Id) async throws {
        try await db.write { db in try Book.deleteOne(db, key: id) }
    }

    func saveProgress(for id: Book.Id, locator: Locator) async throws {
        guard let json = locator.jsonString else {
            return
        }

        try await db.write { db in
            try db.execute(literal: """
                UPDATE book
                   SET locator = \(json), progression = \(locator.locations.totalProgression ?? 0)
                 WHERE id = \(id)
            """)
        }
    }

    func savePreferences<Preferences: Encodable>(_ preferences: Preferences, of id: Book.Id) async throws {
        try await db.write { db in
            guard var book = try Book.fetchOne(db, key: id) else {
                return
            }

            try book.setPreferences(preferences)
            try book.save(db)
        }
    }
}
