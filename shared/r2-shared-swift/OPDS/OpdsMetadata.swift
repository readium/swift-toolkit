//
//  FeedMetadata.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// OPDS metadata properties.
public class OpdsMetadata {
    public var title: String
    public var numberOfItem: Int?
    public var itemsPerPage: Int?
    public var currentPage: Int?
    public var modified: Date?
    public var position: Int?
    public var rdfType: String?

    init(title: String) {
        self.title = title
    }
}
