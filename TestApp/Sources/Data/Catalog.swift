//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import GRDB

/// Represents an OPDS catalog.
struct Catalog: Codable, Hashable, Identifiable {
    struct Id: EntityId { let rawValue: Int64 }
    
    var id: Id?
    var title: String
    var url: String
    var created: Date
    
    init(id: Id? = nil, title: String, url: String, created: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.created = created
    }
}

extension Catalog: TableRecord, FetchableRecord, PersistableRecord {
    enum Columns: String, ColumnExpression {
        case id, title, url, created
    }
}

final class CatalogRepository {
    private let db: Database
    
    init(db: Database) {
        self.db = db
    }
    
    func all() -> AnyPublisher<[Catalog]?, Never> {
        db.observe {
            try Catalog.order(Catalog.Columns.title).fetchAll($0)
        }
    }
    
    func save(_ catalog: inout Catalog) async throws {
        catalog = try await db.write { [catalog] db in
            try catalog.saved(db)
        }
    }
    
    func delete(ids: [Catalog.Id]) async throws {
        try await db.write { db in
            try Catalog.deleteAll(db, ids: ids)
        }
    }
}
