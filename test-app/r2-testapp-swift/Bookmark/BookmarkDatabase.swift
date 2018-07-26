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
    /// Shared instance.
    public static let shared = BookmarkDatabase()
    
    /// Connection.
    let connection: Connection
    /// Tables.
    let bookmarkTable: BookmarkDBTable!
    
    private init() {
        do {
            var url = try FileManager.default.url(for: .libraryDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            
            url.appendPathComponent("bookmarkdatabase.sqlite")
            connection = try Connection(url.absoluteString)
            bookmarkTable = BookmarkDBTable(connection)
        } catch {
            fatalError("Error initializing db.")
        }
    }
}

class BookmarkDBTable {
    /// Table.
    
    let bookmarkTable = Table("bookmarkTable")
    
    let dbID = Expression<Int64>("dbID")
    let createdDate = Expression<Date>("createdDate")
    
    let publicationID = Expression<String>("publicationID")
    let spineIndex = Expression<Int>("spineIndex")
    let progress = Expression<Double>("progress")
    let description =  Expression<String>("description")
    
    init(_ connection: Connection) {
        
        _ = try? connection.run(bookmarkTable.create(temporary: false, ifNotExists: true) { t in
            t.column(dbID, primaryKey: PrimaryKey.autoincrement)
            t.column(createdDate)
            t.column(publicationID)
            t.column(spineIndex)
            t.column(progress)
            t.column(description)
        })
    }
    
    func insert(newBookmark: Bookmark) throws -> Int64 {
        let db = BookmarkDatabase.shared.connection
        
        let insertQuery = bookmarkTable.insert(
            createdDate <- newBookmark.createdDate,
            publicationID <- newBookmark.publicationID,
            spineIndex <- newBookmark.spineIndex,
            progress <- newBookmark.progress,
            description <- newBookmark.description
        )
        
       return try db.run(insertQuery)
    }
    
    func delete(theBookmark: Bookmark) throws -> Bool {
        return try delete(bookmarkID: theBookmark.dbID)
    }
    
    func delete(bookmarkID: Int64) throws -> Bool {
        let db = BookmarkDatabase.shared.connection
        let bookmark = bookmarkTable.filter(self.dbID == bookmarkID)
        
        // Check if empty.
        guard try db.scalar(bookmark.count) > 0 else {
            //throw LcpError.licenseNotFound
            return false
        }
        
        try db.run(bookmark.delete())
        return true
    }
    
    func bookmarkList(for thePublicationID:String?=nil, theSpineIndex:Int?=nil) throws -> [Bookmark]? {
        
        let db = BookmarkDatabase.shared.connection
        // Check if empty.
        guard try db.scalar(bookmarkTable.count) > 0 else {
            return nil
        }
        
        let resultList = try { () -> AnySequence<Row> in
            if let fetchingID = thePublicationID {
                if let fetchingIndex = theSpineIndex {
                    let query = self.bookmarkTable.filter(self.publicationID == fetchingID && self.spineIndex == fetchingIndex)
                    return try db.prepare(query)
                }
                let query = self.bookmarkTable.filter(self.publicationID == fetchingID)
                return try db.prepare(query)
            }
            return try db.prepare(self.bookmarkTable)
        } ()
        
        let bookmarkList = resultList.map { (bookmarkRow) -> Bookmark in
            let thisDBID = bookmarkRow[dbID]
            let thisCreatedDate = bookmarkRow[createdDate]
            let thisPublicationID = bookmarkRow[publicationID]
            let thisSpineIndex = bookmarkRow[spineIndex]
            let thisProgress = bookmarkRow[progress]
            let thisDescription = bookmarkRow[description]
            
            let theBookmark = Bookmark(dbID: thisDBID, date: thisCreatedDate, spineIndex: thisSpineIndex, progress: thisProgress, description: thisDescription, publicationID: thisPublicationID)
            return theBookmark
        }
        
        return bookmarkList
    }
}
