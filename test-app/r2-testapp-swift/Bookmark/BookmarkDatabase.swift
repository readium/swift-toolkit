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
         
//          if connection.userVersion == 0 {
//            // handle first migration
//            connection.userVersion = 1
//            // upgrade database columns
//          }

          
        } catch {
            fatalError("Error initializing db.")
        }
    }
}
class BookmarksTable {
  
    let tableName = Table("BOOKMARKS")
    
    let bookmarkID = Expression<Int64>("id")
    let publicationID = Expression<String>("publicationID")
  
    let resourceIndex = Expression<Int>("resourceIndex")
    let resourceHref = Expression<String>("resourceHref")
    let resourceTitle =  Expression<String>("resourceTitle")
  
    let progression = Expression<Double>("progression")
    let timestamp = Expression<Date>("timestamp")

  
    init(_ connection: Connection) {
        
        _ = try? connection.run(tableName.create(temporary: false, ifNotExists: true) { t in
            t.column(bookmarkID, primaryKey: PrimaryKey.autoincrement)
            t.column(timestamp)
            t.column(publicationID)
            t.column(resourceHref)
            t.column(resourceIndex)
            t.column(progression)
            t.column(resourceTitle)
        })
      connection.userVersion = 0
    }
    
    func insert(newBookmark: Bookmark) throws -> Int64? {
        let db = BookmarkDatabase.shared.connection
        
        let bookmark = tableName.filter(self.publicationID == newBookmark.publicationID && self.resourceHref == newBookmark.resourceHref && self.resourceIndex == newBookmark.resourceIndex && self.progression == newBookmark.progression)
        
        // Check if empty.
        guard try db.scalar(bookmark.count) == 0 else {
            return nil
        }
        
        let insertQuery = tableName.insert(
            timestamp <- newBookmark.timestamp,
            publicationID <- newBookmark.publicationID,
            resourceHref <- newBookmark.resourceHref,
            resourceIndex <- newBookmark.resourceIndex,
            progression <- newBookmark.progression,
            resourceTitle <- newBookmark.resourceTitle
        )
        
       return try db.run(insertQuery)
    }
    
    func delete(bookmark: Bookmark) throws -> Bool {
        return try delete(bookmarkID: bookmark.bookmarkID)
    }
    
    func delete(bookmarkID: Int64) throws -> Bool {
        let db = BookmarkDatabase.shared.connection
        let bookmark = tableName.filter(self.bookmarkID == bookmarkID)
        
        // Check if empty.
        guard try db.scalar(bookmark.count) > 0 else {
            return false
        }
        
        try db.run(bookmark.delete())
        return true
    }
    
    func bookmarkList(for publicationID:String?=nil, resourceIndex:Int?=nil) throws -> [Bookmark]? {
        
        let db = BookmarkDatabase.shared.connection
        // Check if empty.
        guard try db.scalar(tableName.count) > 0 else {
            return nil
        }
        
        let resultList = try { () -> AnySequence<Row> in
            if let fetchingID = publicationID {
                if let fetchingIndex = resourceIndex {
                    let query = self.tableName.filter(self.publicationID == fetchingID && self.resourceIndex == fetchingIndex)
                    return try db.prepare(query)
                }
                let query = self.tableName.filter(self.publicationID == fetchingID)
                return try db.prepare(query)
            }
            return try db.prepare(self.tableName)
        } ()
        
        let bookmarkList = resultList.map { (bookmarkRow) -> Bookmark in
            let _bookmarkID = bookmarkRow[self.bookmarkID]
            let _timestamp = bookmarkRow[self.timestamp]
            let _publicationID = bookmarkRow[self.publicationID]
            let _resourceHref = bookmarkRow[self.resourceHref]
            let _resourceIndex = bookmarkRow[self.resourceIndex]
            let _progression = bookmarkRow[self.progression]
            let _resourceTitle = bookmarkRow[self.resourceTitle]
            
            let bookmark = Bookmark(bookmarkID: _bookmarkID, timestamp: _timestamp, resourceHref: _resourceHref, resourceIndex: _resourceIndex, progression: _progression, resourceTitle: _resourceTitle, publicationID: _publicationID)
            return bookmark
        }
        
        return bookmarkList
    }
}

extension Connection {
  public var userVersion: Int32 {
    get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
    set { try! run("PRAGMA user_version = \(newValue)") }
  }
}
