//
//  BookmarkDatabase.swift
//  r2-testapp-swift
//
//  Created by Senda Li on 2018/7/20.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SQLite
import R2Shared

final class BookmarkDatabase {
    // Shared instance.
    public static let shared = BookmarkDatabase()
    
    // Connection.
    let connection: Connection
    // The DB table for bookmark.
    let bookmarks: BookmarksTable!
    
    private init() {
        do {
            var url = try FileManager.default.url(for: .libraryDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            
            url.appendPathComponent("bookmarks_database")
            connection = try Connection(url.absoluteString)
            bookmarks = BookmarksTable(connection)
         
          
        } catch {
            fatalError("Error initializing db.")
        }
    }
}

class BookmarksTable {
  
    let tableName = Table("BOOKMARKS")
    
    let bookmarkID = Expression<Int64>("id")
    let bookID = Expression<Int64>("bookID")
  
    let resourceIndex = Expression<Int>("resourceIndex")
    let resourceHref = Expression<String>("resourceHref")
    let resourceTitle =  Expression<String>("resourceTitle")
    let resourceType =  Expression<String>("resourceType")

    let locations = Expression<String>("locations")
    let locatorText = Expression<String>("locatorText")
    let creationDate = Expression<Date>("creationDate")

  
    init(_ connection: Connection) {
      //      connection.userVersion = 0
        if connection.userVersion == 0 {
          // handle first migration
          connection.userVersion = 1
          // upgrade database columns
          // drop table and recreate, this will delete all prior bookmarks
          _ = try? connection.run(tableName.drop())
        }
      
        _ = try? connection.run(tableName.create(temporary: false, ifNotExists: true) { t in
            t.column(bookmarkID, primaryKey: PrimaryKey.autoincrement)
            t.column(creationDate)
            t.column(bookID)
            t.column(resourceHref)
            t.column(resourceIndex)
            t.column(resourceType)
            t.column(locations)
            t.column(locatorText)
            t.column(resourceTitle)
        })
    }
    
    func insert(newBookmark: Bookmark) throws -> Int64? {
        let db = BookmarkDatabase.shared.connection
        
        let bookmark = tableName.filter(self.bookID == newBookmark.bookID && self.resourceHref == newBookmark.locator.href && self.resourceIndex == newBookmark.resourceIndex && self.locations == (newBookmark.locator.locations.jsonString ?? ""))
        
        // Check if empty.
        guard try db.count(bookmark) == 0 else {
            return nil
        }
        
        let insertQuery = tableName.insert(
            creationDate <- newBookmark.creationDate,
            bookID <- newBookmark.bookID,
            resourceHref <- newBookmark.locator.href,
            resourceIndex <- newBookmark.resourceIndex,
            resourceType <- newBookmark.locator.type,
            locations <- newBookmark.locator.locations.jsonString ?? "",
            locatorText <- newBookmark.locator.text.jsonString ?? "",
            resourceTitle <- newBookmark.locator.title ?? ""
        )
        
       return try db.run(insertQuery)
    }
    
    func delete(bookmark: Bookmark) throws -> Bool {
        return try delete(bookmarkID: bookmark.id!)
    }
    
    func delete(bookmarkID: Int64) throws -> Bool {
        let db = BookmarkDatabase.shared.connection
        let bookmark = tableName.filter(self.bookmarkID == bookmarkID)
        
        // Check if empty.
        guard try db.count(bookmark) > 0 else {
            return false
        }
        
        try db.run(bookmark.delete())
        return true
    }
    
    func bookmarkList(for bookID: Int64? = nil, resourceIndex: Int? = nil) throws -> [Bookmark]? {
        
        let db = BookmarkDatabase.shared.connection
        // Check if empty.
        guard try db.count(tableName) > 0 else {
            return nil
        }
        
        let resultList = try { () -> AnySequence<Row> in
            if let fetchingID = bookID {
                if let fetchingIndex = resourceIndex {
                    let query = self.tableName.filter(self.bookID == fetchingID && self.resourceIndex == fetchingIndex)
                    return try db.prepare(query)
                }
                let query = self.tableName.filter(self.bookID == fetchingID)
                return try db.prepare(query)
            }
            return try db.prepare(self.tableName)
        } ()
        
        return resultList.map { row in
            Bookmark(
                id: row[self.bookmarkID],
                bookID: row[self.bookID],
                resourceIndex: row[self.resourceIndex],
                locator: Locator(
                    href: row[self.resourceHref],
                    type: row[self.resourceType],
                    title: row[self.resourceTitle],
                    locations: Locator.Locations(jsonString: row[self.locations]),
                    text: Locator.Text(jsonString: row[self.locatorText])
                ),
                creationDate: row[self.creationDate]
            )
        }
    }
}
