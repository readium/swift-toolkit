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
import R2Shared

class BookmarkDataSource: Loggable {
    
    let bookID: Int64?
    private(set) var bookmarks = [Bookmark]()
    
    init() {
        self.bookID = nil
        self.reloadBookmarks()
    }
    
    init(bookID: Int64) {
        self.bookID = bookID
        self.reloadBookmarks()
    }
    
    func reloadBookmarks() {
        if let list = try? BookmarkDatabase.shared.bookmarks.bookmarkList(for: self.bookID) {
            self.bookmarks = list 
            self.bookmarks.sort { (b1, b2) -> Bool in
                if b1.resourceIndex == b2.resourceIndex {
                    let locations1 = b1.locator.locations
                    let locations2 = b2.locator.locations
                    if let position1 = locations1.position, let position2 = locations2.position {
                        return position1 < position2
                    } else if let progression1 = locations1.progression, let progression2 = locations2.progression {
                        return progression1 < progression2
                    }
                }
                return b1.resourceIndex < b2.resourceIndex
            }
        }
    }
    
    var count: Int {
        return bookmarks.count
    }
    
    func bookmark(at index: Int) -> Bookmark? {
        guard bookmarks.indices.contains(index) else {
            return nil
        }
        return bookmarks[index]
    }
    
    func addBookmark(bookmark: Bookmark) -> Bool {
        do {
            if let bookmarkID = try BookmarkDatabase.shared.bookmarks.insert(newBookmark: bookmark) {
                bookmark.id = bookmarkID
                self.reloadBookmarks()
              return true
            }
          return false
        } catch {
            log(.error, error)
            return false
        }
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
