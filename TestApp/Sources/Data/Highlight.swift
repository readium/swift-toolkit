//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import GRDB
import ReadiumNavigator
import ReadiumShared
import UIKit

enum HighlightColor: UInt8, Codable, SQLExpressible {
    case red = 1
    case green = 2
    case blue = 3
    case yellow = 4
}

extension HighlightColor {
    var uiColor: UIColor {
        switch self {
        case .red:
            return .red
        case .green:
            return .green
        case .blue:
            return .blue
        case .yellow:
            return .yellow
        }
    }
}

struct Highlight: Codable {
    struct Id: EntityId { let rawValue: Int64 }

    let id: Id?
    /// Foreign key to the publication.
    var bookId: Book.Id
    /// Location in the publication.
    var locator: Locator
    /// Color of the highlight.
    var color: HighlightColor
    /// Date of creation.
    var created: Date = .init()
    /// Total progression in the publication.
    var progression: Double?

    init(
        id: Id? = nil,
        bookId: Book.Id,
        locator: Locator,
        color: HighlightColor,
        created: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.locator = locator
        progression = locator.locations.totalProgression
        self.color = color
        self.created = created
    }
}

extension Highlight: TableRecord, FetchableRecord, PersistableRecord {
    enum Columns: String, ColumnExpression {
        case id, bookId, locator, color, created, progression
    }
}

struct HighlightNotFoundError: Error {}

final class HighlightRepository {
    private let db: Database

    init(db: Database) {
        self.db = db
    }

    func all(for bookId: Book.Id) -> AnyPublisher<[Highlight], Error> {
        db.observe { db in
            try Highlight
                .filter(Highlight.Columns.bookId == bookId)
                .order(Highlight.Columns.progression)
                .fetchAll(db)
        }
    }

    func highlight(for highlightId: Highlight.Id) -> AnyPublisher<Highlight, Error> {
        db.observe { db in
            try Highlight
                .filter(Highlight.Columns.id == highlightId)
                .fetchOne(db)
                .orThrow(HighlightNotFoundError())
        }
    }

    @discardableResult
    func add(_ highlight: Highlight) async throws -> Highlight.Id {
        try await db.write { db in
            try highlight.insert(db)
            return Highlight.Id(rawValue: db.lastInsertedRowID)
        }
    }

    func update(_ id: Highlight.Id, color: HighlightColor) async throws {
        try await db.write { db in
            let filtered = Highlight.filter(Highlight.Columns.id == id)
            let assignment = Highlight.Columns.color.set(to: color)
            try filtered.updateAll(db, onConflict: nil, assignment)
        }
    }

    func remove(_ id: Highlight.Id) async throws {
        try await db.write { db in try Highlight.deleteOne(db, key: id) }
    }
}

// for the default SwiftUI support
extension Highlight: Hashable {}
