//
//  Catalog.swift
//  TestApp
//
//  Created by Steven Zeck on 5/24/22.
//

import Combine
import Foundation
import GRDB
import GRDBQuery

struct Catalog: Codable, Hashable {
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

struct CatalogFeedListRequest: Queryable {
    static var defaultValue: [Catalog] { [] }
    
    func publisher(in dbQueue: DatabaseQueue) -> DatabasePublishers.Value<[Catalog]> {
        ValueObservation
            .tracking { db in try Catalog.order(Catalog.Columns.created).fetchAll(db) }
            .publisher(in: dbQueue, scheduling: .immediate)
    }
}
