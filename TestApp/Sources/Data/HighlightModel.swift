//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import GRDB
import R2Shared
import R2Navigator
import UIKit

struct HighlightRecord: Codable {
    typealias Id = String
    
    let id: Id
    /// Foreign key to the publication.
    var bookId: Book.Id
    /// Location in the publication.
    var locator: Locator
    /// Color of the highlight.
    var color: HighlightColor
    /// Date of creation.
    var created: Date = Date()
    
    init(id: Id, bookId: Book.Id, locator: Locator, color: HighlightColor, created: Date = Date()) {
        self.id = id
        self.bookId = bookId
        self.locator = locator
        self.color = color
        self.created = created
    }
    
    init(bookId: Book.Id, highlight: Highlight) {
        self.id = highlight.id.uuidString
        self.bookId = bookId
        self.locator = highlight.locator
        self.color = highlight.color
        self.created = Date()
    }
}

extension HighlightRecord: TableRecord, FetchableRecord, PersistableRecord {
    enum Columns: String, ColumnExpression {
        case id, bookId, locator, color, created
    }
}

final class HighlightRepository {
    private let db: Database
    
    init(db: Database) {
        self.db = db
    }
    
    func all(for bookId: Book.Id) -> AnyPublisher<[HighlightRecord], Error> {
        db.observe { db in
            try HighlightRecord
                .filter(HighlightRecord.Columns.bookId == bookId)
                .order(HighlightRecord.Columns.id) // TODO: order by some kind of progression!
                .fetchAll(db)
        }
    }
    
    func add(_ highlight: HighlightRecord) -> AnyPublisher<HighlightRecord.Id, Error> {
        return db.write { db in
            try highlight.insert(db)
            return highlight.id
        }.eraseToAnyPublisher()
    }
    
    func update(_ id: HighlightRecord.Id, color: HighlightColor) -> AnyPublisher<Void, Error> {
        return db.write { db in
            let filtered = HighlightRecord.filter(HighlightRecord.Columns.id == id)
            let assignment = HighlightRecord.Columns.color.set(to: color)
            try filtered.updateAll(db, onConflict: nil, assignment)
        }.eraseToAnyPublisher()
    }
        
    func remove(_ id: HighlightRecord.Id) -> AnyPublisher<Void, Error> {
        db.write { db in try HighlightRecord.deleteOne(db, key: id) }
    }
}

extension HighlightColor: DatabaseValueConvertible {
    
}
