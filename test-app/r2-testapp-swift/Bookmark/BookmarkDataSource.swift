//
//  BookmarkDataSource.swift
//  r2-testapp-swift
//
//  Created by Senda Li on 2018/7/19.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

class Bookmark {
    var dbID: Int64
    let createdDate: Date
    
    let publicationID: String
    let spineIndex: Int
    let progress: Double
    let description: String
    
    
    init() {
        dbID = 14290490101840
        spineIndex = 1
        progress = 0.45
        description = "The bookmark description"
        
        createdDate = Date(timeIntervalSinceNow: -99999999999)
        publicationID = "The ID for publication"
    }
    
    init(dbID:Int64 = 0, date:Date = Date(),
         spineIndex:Int, progress: Double, description: String, publicationID: String) {
        
        self.publicationID = publicationID
        self.description = description
        self.spineIndex = spineIndex
        self.progress = progress
        
        self.dbID = dbID
        self.createdDate = date
    }
}

class BookmarkDataSource {
    
    let publicationID :String?
    private(set) var bookmarkList = [Bookmark]()
    
    init() {
        self.publicationID = nil
        self.reloadDate()
    }
    
    init(thePublicationID: String) {
        
        self.publicationID = thePublicationID
        self.reloadDate()
    }
    
    func reloadDate() {
        
        if let theList = try? BookmarkDatabase.shared.bookmarkTable.bookmarkList(for: self.publicationID) {
            self.bookmarkList = theList ?? [Bookmark]()
            self.bookmarkList.sort { (thisBookmark, anotherBookmark) -> Bool in
                if thisBookmark.spineIndex == anotherBookmark.spineIndex {
                    return thisBookmark.progress < anotherBookmark.progress
                }
                return thisBookmark.spineIndex < anotherBookmark.spineIndex
            }
        }
    }
    
    func bookmarkCount() -> Int {
        return bookmarkList.count
    }
    
    func bookmark(at index: Int) -> Bookmark? {
        if index < 0 || index >= bookmarkList.count {
            return nil
        }
        return bookmarkList[index]
    }
    
    func addBookmark(newBookmark: Bookmark) -> Bool {
        
        if let dbID = try? BookmarkDatabase.shared.bookmarkTable.insert(newBookmark: newBookmark) {
            newBookmark.dbID = dbID
            //bookmarkList.append(newBookmark)
            self.reloadDate()
        }
        return true
    }
    
    func removeBookmark(index: Int) -> Bool {
        if index < 0 || index >= bookmarkList.count {
            return false
        }
        let theBookmark = bookmarkList[index]
        guard let result =  try? BookmarkDatabase.shared.bookmarkTable.delete(theBookmark:theBookmark) else {
            return false
        }
        
        if result {
            bookmarkList.remove(at:index)
            return true
        }
        return false
    }
    
    func bookmarked(index: Int, progress: Double) -> Bool {
        return false
    }
}
