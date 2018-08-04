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
    var bookmarkID: Int64
    let publicationID: String

    let resourceHref: String
    let resourceIndex: Int
    let resourceTitle: String

    let progression: Double
    let timestamp: Date

    init(bookmarkID:Int64 = 0, timestamp:Date = Date(),
         resourceHref:String, resourceIndex:Int, progression: Double, resourceTitle: String, publicationID: String) {
        
        self.bookmarkID = bookmarkID
        self.publicationID = publicationID
      
        self.resourceHref = resourceHref
        self.resourceIndex = resourceIndex
        self.resourceTitle = resourceTitle
      
        self.progression = progression
        self.timestamp = timestamp
      
    }
}

class BookmarkDataSource {
    
    let publicationID :String?
    private(set) var bookmarks = [Bookmark]()
    
    init() {
        self.publicationID = nil
        self.reloadBookmarks()
    }
    
    init(publicationID: String) {
        self.publicationID = publicationID
        self.reloadBookmarks()
    }
    
    func reloadBookmarks() {
        if let list = try? BookmarkDatabase.shared.bookmarks.bookmarkList(for: self.publicationID) {
            self.bookmarks = list ?? [Bookmark]()
            self.bookmarks.sort { (b1, b2) -> Bool in
                if b1.resourceIndex == b2.resourceIndex {
                    return b1.progression < b2.progression
                }
                return b1.resourceIndex < b2.resourceIndex
            }
        }
    }
    
    var count: Int {
        return bookmarks.count
    }
    
    func bookmark(at index: Int) -> Bookmark? {
        if index < 0 || index >= bookmarks.count {
            return nil
        }
        return bookmarks[index]
    }
    
    func addBookmark(bookmark: Bookmark) -> Bool {
        if let addedBookmarkID = try? BookmarkDatabase.shared.bookmarks.insert(newBookmark: bookmark) {
          if let bookmarkID = addedBookmarkID {
            bookmark.bookmarkID = bookmarkID
            self.reloadBookmarks()
            return true
          }
        }
        return false
    }
    
    func removeBookmark(index: Int) -> Bool {
        if index < 0 || index >= bookmarks.count {
            return false
        }
        let bookmark = bookmarks[index]
        guard let deleted =  try? BookmarkDatabase.shared.bookmarks.delete(bookmark:bookmark) else {
            return false
        }
        
        if deleted {
            bookmarks.remove(at:index)
            return true
        }
        return false
    }
    
    func bookmarked(index: Int, progress: Double) -> Bool {
        return false
    }
}
