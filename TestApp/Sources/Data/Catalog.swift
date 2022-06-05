//
//  Catalog.swift
//  TestApp
//
//  Created by Steven Zeck on 5/24/22.
//

import Combine
import Foundation
import GRDB

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
    
    func preloadTestFeeds() async {
        let version = 2
        let VERSION_KEY = "OPDS_CATALOG_VERSION"
        var OPDS2Catalog = Catalog(title: "OPDS 2.0 Test Catalog", url: "https://test.opds.io/2.0/home.json")
        var OTBCatalog = Catalog(title: "Open Textbooks Catalog", url: "http://open.minitex.org/textbooks")
        var SEBCatalog = Catalog(title: "Standard eBooks Catalog", url: "https://standardebooks.org/opds/all")
        
        let oldversion = UserDefaults.standard.integer(forKey: VERSION_KEY)
        if (oldversion < version) {
            UserDefaults.standard.set(version, forKey: VERSION_KEY)
            do {
                try await saveCatalog(&OPDS2Catalog)
                try await saveCatalog(&OTBCatalog)
                try await saveCatalog(&SEBCatalog)
            } catch {
                
            }
        }
    }
    
    func all() -> AnyPublisher<[Catalog]?, Never> {
        ValueObservation
            .tracking(Catalog.order(Catalog.Columns.title).fetchAll)
            .publisher(in: db.databaseReader, scheduling: .immediate)
            .assertNoFailure()
            .eraseToAnyPublisher()
    }
    
    func saveCatalog(_ catalog: inout Catalog) async throws {
        catalog = try await db.writer.write { [catalog] db in
            try catalog.saved(db)
        }
    }
    
    func deleteCatalogs(ids: [Catalog.Id]) async throws {
        try await db.writer.write { db in
            _ = try Catalog.deleteAll(db, ids: ids)
        }
    }
}
