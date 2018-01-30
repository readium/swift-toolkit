//
//  FeedMetadata.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public class OpdsMetadata {
    public var title: String
    public var numberOfItem: Int?
    public var itemsPerPage: Int?
    public var currentPage: Int?
    public var modified: Date?
    public var position: Int?
    public var type: String?

    init(title: String) {
        self.title = title
    }
}
