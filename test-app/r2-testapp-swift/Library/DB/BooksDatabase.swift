//
//  BooksDatabase.swift
//  r2-testapp-swift
//
//  Created by Aferdita Muriqi on 2018/9/05.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared
import SQLite

final class BooksDatabase {
    // Shared instance.
    public static let shared = BooksDatabase()
    
    // Connection.
    let connection: Connection
    // The DB table for books.
    let books: BooksTable!
    
    private init() {
        do {
            var url = try FileManager.default.url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil, create: true
            )

            url.appendPathComponent("books_database")
            connection = try Connection(url.absoluteString)
            books = BooksTable(connection)
            
        } catch {
            fatalError("Error initializing db.")
        }
    }
}

class Book: Loggable {
    let id: Int64
    let creation:Date
    let href: String
    let title: String
    let author: String?
    let identifier: String?
    let cover: Data?
    var progression: String?
    
    enum Error: Swift.Error {
        case notFound(Swift.Error?)
    }
    
    func url() throws -> URL {
        // Absolute URL.
        if let url = URL(string: href), url.scheme != nil {
            return url
        }
        
        // Absolute file path.
        if href.hasPrefix("/") {
            return URL(fileURLWithPath: href)
        }
        
        do {
            // Path relative to Documents/.
            let files = FileManager.default
            let documents = try files.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

            let documentURL = documents.appendingPathComponent(href)
            if (try? documentURL.checkResourceIsReachable()) == true {
                return documentURL
            }
    
            // Path relative to the Samples/ directory in the App bundle.
            if
                let sampleURL = Bundle.main.url(forResource: href, withExtension: nil, subdirectory: "Samples"),
                (try? sampleURL.checkResourceIsReachable()) == true
            {
                return sampleURL
            }
        } catch {
            throw Error.notFound(error)
        }
        
        throw Error.notFound(nil)
    }
    
    init(
        id: Int64 = 0,
        creation:Date = Date(),
        href: String,
        title: String,
        author: String?,
        identifier: String?,
        cover: Data?,
        progression: String? = nil
    ) {
        self.id = id
        self.creation = creation
        self.href = href
        self.title = title
        self.author = author
        self.identifier = identifier
        self.cover = cover
        self.progression = progression
        
    }
    
    var progressionLocator: Locator? {
        do {
            return try progression.flatMap { try Locator(jsonString: $0) }
        } catch {
            log(.error, "Can't parse Book.progression: \(error.localizedDescription)")
            return nil
        }
    }
    
}

class BooksTable {
    
    let books = Table("BOOKS")
    
    let ID = Expression<Int64>("id")
    let IDENTIFIER = Expression<String?>("identifier")
    let HREF = Expression<String>("href")
    let TITLE = Expression<String>("title")
    let AUTHOR = Expression<String?>("author")
    let COVER = Expression<Data?>("cover")
    let CREATION = Expression<Date>("creationDate")
    let PROGRESSION = Expression<String?>("progression")
    
    init(_ connection: Connection) {
        
        connection.userVersion = 0
        _ = try? connection.run(books.create(temporary: false, ifNotExists: true) { t in
            t.column(ID, primaryKey: PrimaryKey.autoincrement)
            t.column(IDENTIFIER)
            t.column(HREF)
            t.column(TITLE)
            t.column(AUTHOR)
            t.column(COVER)
            t.column(CREATION)
            t.column(PROGRESSION)
        })
    }
    
    func insert(book: Book, allowDuplicate:Bool = false) throws -> Int64? {
        let db = BooksDatabase.shared.connection
        
        if !allowDuplicate {
            guard !exists(book) else {
                return nil
            }
        }
        
        let query = books.insert(
            IDENTIFIER <- book.identifier,
            HREF <- book.href,
            TITLE <- book.title,
            AUTHOR <- book.author,
            COVER <- book.cover,
            CREATION <- book.creation,
            PROGRESSION <- book.progression
        )
        
        return try db.run(query)
    }
    
    private func exists(_ book: Book) -> Bool {
        guard let identifier = book.identifier else {
            return false
        }
        let db = BooksDatabase.shared.connection
        let filter = books.filter(self.IDENTIFIER == identifier)
        return ((try? db.count(filter)) ?? 0) != 0
    }
    
    func delete(_ book: Book) throws -> Bool {
        return try delete(book.id)
    }
    
    private func delete(_ ID: Int64) throws -> Bool {
        let db = BooksDatabase.shared.connection
        let book = books.filter(self.ID == ID)
        
        // Check if empty.
        guard try db.count(book) > 0 else {
            return false
        }
        
        try db.run(book.delete())
        return true
    }
    
    @discardableResult
    func saveProgression(_ locator: Locator?, of book: Book) throws -> Bool {
        let db = BooksDatabase.shared.connection
        let bookFilter = books.filter(ID == book.id)
        
        // Check if empty.
        guard try db.count(bookFilter) > 0 else {
            return false
        }
        
        book.progression = locator?.jsonString
        try db.run(bookFilter.update(PROGRESSION <- book.progression))
        return true
    }
    
    func all() throws -> [Book] {
        
        let db = BooksDatabase.shared.connection
        // Check if empty.
        guard try db.count(books) > 0 else {
            return []
        }
        
        let resultList = try { () -> AnySequence<Row> in
            return try db.prepare(self.books.order(self.ID.desc))
            } ()
        
        let bookList = resultList.map { (bookRow) -> Book in
            
            let _ID = bookRow[self.ID]
            let _identifier = bookRow[self.IDENTIFIER]
            let _href = bookRow[self.HREF]
            let _title = bookRow[self.TITLE]
            let _author = bookRow[self.AUTHOR]
            let _cover = bookRow[self.COVER]
            let _creation = bookRow[self.CREATION]
            let _progression = bookRow[self.PROGRESSION]
            
            let book = Book(id: _ID, creation: _creation, href: _href, title: _title, author: _author, identifier: _identifier, cover: _cover, progression: _progression)
            return book
        }
        
        return bookList
    }
}
