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
    let publicationID = Expression<String>("publicationID")
  
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
            t.column(publicationID)
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
        
        let bookmark = tableName.filter(self.publicationID == newBookmark.publicationID && self.resourceHref == newBookmark.resourceHref && self.resourceIndex == newBookmark.resourceIndex && self.locations == newBookmark.locations!.toString()!)
        
        // Check if empty.
        guard try db.scalar(bookmark.count) == 0 else {
            return nil
        }
        
        let insertQuery = tableName.insert(
            creationDate <- newBookmark.creationDate,
            publicationID <- newBookmark.publicationID,
            resourceHref <- newBookmark.resourceHref,
            resourceIndex <- newBookmark.resourceIndex,
            resourceType <- newBookmark.resourceType,
            locations <- newBookmark.locations!.toString()!,
            locatorText <- newBookmark.locatorText.toString()!,
            resourceTitle <- newBookmark.resourceTitle
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
            let _creationDate = bookmarkRow[self.creationDate]
            let _publicationID = bookmarkRow[self.publicationID]
            let _resourceHref = bookmarkRow[self.resourceHref]
            let _resourceIndex = bookmarkRow[self.resourceIndex]
            let _locations = bookmarkRow[self.locations]
            let _locatorText = bookmarkRow[self.locatorText]
            let _resourceTitle = bookmarkRow[self.resourceTitle]
            let _resourceType = bookmarkRow[self.resourceType]

            let bookmark = Bookmark(bookID: 0, publicationID: _publicationID, resourceIndex: _resourceIndex, resourceHref: _resourceHref, resourceType: _resourceType, resourceTitle: _resourceTitle, location: Locations(fromString: _locations), locatorText: LocatorText(fromString: _locatorText), creationDate: _creationDate, id: _bookmarkID)
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
