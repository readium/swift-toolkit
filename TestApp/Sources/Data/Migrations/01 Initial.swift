//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import GRDB

/// This database migration will create the SQL schema and insert some initial data.
struct InitialMigration: DatabaseMigration {
    let version = 1
    
    func run(on db: GRDB.Database) throws {
        try createSchema(on: db)
        try bootstrapData(on: db)
    }
    
    private func createSchema(on db: GRDB.Database) throws {
        try db.create(table: "book", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("identifier", .text)
            t.column("title", .text).notNull()
            t.column("authors", .text)
            t.column("type", .text).notNull()
            t.column("path", .text).notNull()
            t.column("coverPath", .text)
            t.column("locator", .text)
            t.column("progression", .integer).notNull().defaults(to: 0)
            t.column("created", .datetime).notNull()
        }
        
        try db.create(table: "bookmark", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("bookId", .integer).references("book", onDelete: .cascade).notNull()
            t.column("locator", .text)
            t.column("progression", .double).notNull()
            t.column("created", .datetime).notNull()
        }
        
        try db.create(table: "highlight", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("bookId", .integer).references("book", onDelete: .cascade).notNull()
            t.column("locator", .text)
            t.column("progression", .double).notNull()
            t.column("color", .integer).notNull()
            t.column("created", .datetime).notNull()
        }
        
        // create an index to make sorting by progression faster
        try db.create(index: "index_highlight_progression", on: "highlight", columns: ["bookId", "progression"], ifNotExists: true)
        try db.create(index: "index_bookmark_progression", on: "bookmark", columns: ["bookId", "progression"], ifNotExists: true)
        
        try db.create(table: "catalog", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("title", .text)
            t.column("url", .text).notNull()
            t.column("created", .datetime).notNull()
        }
    }
    
    private func bootstrapData(on db: GRDB.Database) throws {
        let catalogs = [
            Catalog(title: "OPDS 2.0 Test Catalog", url: "https://test.opds.io/2.0/home.json"),
            Catalog(title: "Open Textbooks Catalog", url: "http://open.minitex.org/textbooks"),
            Catalog(title: "Standard eBooks Catalog", url: "https://standardebooks.org/opds/all"),
        ]
            
        for catalog in catalogs {
            try catalog.save(db)
        }
    }
}
