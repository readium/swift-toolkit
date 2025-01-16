//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import GRDB
import ReadiumShared

struct Bookmark: Codable {
    struct Id: EntityId { let rawValue: Int64 }

    let id: Id?
    /// Foreign key to the publication.
    var bookId: Book.Id
    /// Location in the publication.
    var locator: Locator
    /// Progression in the publication, extracted from the locator.
    var progression: Double?
    /// Date of creation.
    var created: Date = .init()

    init(id: Id? = nil, bookId: Book.Id, locator: Locator, created: Date = Date()) {
        self.id = id
        self.bookId = bookId
        self.locator = locator
        progression = locator.locations.totalProgression
        self.created = created
    }
}

extension Bookmark: TableRecord, FetchableRecord, PersistableRecord {
    enum Columns: String, ColumnExpression {
        case id, bookId, locator, progression, created
    }
}

final class BookmarkRepository {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func all(for bookId: Book.Id) -> AnyPublisher<[Bookmark], Error> {
        db.observe { db in
            try Bookmark
                .filter(Bookmark.Columns.bookId == bookId)
                .order(Bookmark.Columns.progression)
                .fetchAll(db)
        }
    }

    @discardableResult
    func add(_ bookmark: Bookmark) async throws -> Bookmark.Id {
        try await db.write { db in
            try bookmark.insert(db)
            return Bookmark.Id(rawValue: db.lastInsertedRowID)
        }
    }

    func remove(_ id: Bookmark.Id) async throws {
        try await db.write { db in try Bookmark.deleteOne(db, key: id) }
    }
}

// for the default SwiftUI support
extension Bookmark: Hashable {}
