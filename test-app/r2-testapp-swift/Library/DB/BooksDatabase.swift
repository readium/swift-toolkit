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
      var url = try FileManager.default.url(for: .libraryDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil, create: true)
      
      url.appendPathComponent("books_database")
      connection = try Connection(url.absoluteString)
      books = BooksTable(connection)
      
    } catch {
      fatalError("Error initializing db.")
    }
  }
}

class Book{
  let id: Int64
  let creation:Date
  let fileName: String
  let title: String
  let author: String?
  let identifier: String
  let cover: Data?
  let progression: String?

  init(
    id: Int64 = 0,
    creation:Date = Date(),
    fileName:String,
    title:String,
    author:String?,
    identifier: String,
    cover: Data?,
    progression: String? = nil
    ) {
    
    self.id = id
    self.creation = creation
    self.fileName = fileName
    self.title = title
    self.author = author
    self.identifier = identifier
    self.cover = cover
    self.progression = progression

  }
  
}

class BooksTable {
  
  let books = Table("BOOKS")
  
  let ID = Expression<Int64>("id")
  let IDENTIFIER = Expression<String>("identifier")
  let FILENAME = Expression<String>("href")
  let TITLE = Expression<String>("title")
  let AUTHOR = Expression<String?>("author")
  let COVER = Expression<Data?>("cover")
  let CREATION = Expression<Date>("creationDate")
  let PROGRESSION = Expression<String?>("progression")

  init(_ connection: Connection) {
    
    if connection.userVersion == 0 {
      // handle first migration
      connection.userVersion = 1
      // upgrade database columns
      // drop table and recreate, this will delete all prior books
      _ = try? connection.run(books.drop())
    }
    _ = try? connection.run(books.create(temporary: false, ifNotExists: true) { t in
      t.column(ID, primaryKey: PrimaryKey.autoincrement)
      t.column(IDENTIFIER)
      t.column(FILENAME)
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
      FILENAME <- book.fileName,
      TITLE <- book.title,
      AUTHOR <- book.author,
      COVER <- book.cover,
      CREATION <- book.creation,
      PROGRESSION <- book.progression
    )
    
    return try db.run(query)
  }
  
  private func exists(_ book: Book) -> Bool {
    let db = BooksDatabase.shared.connection
    let filter = books.filter(self.IDENTIFIER == book.identifier)
    return ((try? db.scalar(filter.count)) ?? 0) != 0
  }
  
  func delete(_ book: Book) throws -> Bool {
    return try delete(book.id)
  }
  
  private func delete(_ ID: Int64) throws -> Bool {
    let db = BooksDatabase.shared.connection
    let book = books.filter(self.ID == ID)
    
    // Check if empty.
    guard try db.scalar(book.count) > 0 else {
      return false
    }
    
    try db.run(book.delete())
    return true
  }
  
  func all() throws -> [Book] {
    
    let db = BooksDatabase.shared.connection
    // Check if empty.
    guard try db.scalar(books.count) > 0 else {
      return []
    }
    
    let resultList = try { () -> AnySequence<Row> in
      return try db.prepare(self.books.order(self.ID.desc))
      } ()
    
    let bookList = resultList.map { (bookRow) -> Book in
      
      let _ID = bookRow[self.ID]
      let _identifier = bookRow[self.IDENTIFIER]
      let _fileName = bookRow[self.FILENAME]
      let _title = bookRow[self.TITLE]
      let _author = bookRow[self.AUTHOR]
      let _cover = bookRow[self.COVER]
      let _creation = bookRow[self.CREATION]
      let _progression = bookRow[self.PROGRESSION]

      let book = Book(id: _ID, creation: _creation, fileName: _fileName, title: _title, author: _author, identifier: _identifier, cover: _cover, progression: _progression)
      return book
    }
    
    return bookList
  }
}

