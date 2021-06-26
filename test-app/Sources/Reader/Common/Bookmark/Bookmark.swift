//
//  Bookmark.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 04.04.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


public class Bookmark {
    
    public var id: Int64?
    public var bookID: Int64
    public var resourceIndex: Int
    public var locator: Locator
    public var creationDate: Date
    
    public init(id: Int64? = nil, bookID: Int64, resourceIndex: Int, locator: Locator, creationDate: Date = Date()) {
        self.id = id
        self.bookID = bookID
        self.resourceIndex = resourceIndex
        self.locator = locator
        self.creationDate = creationDate
    }

}
