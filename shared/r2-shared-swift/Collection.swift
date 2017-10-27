//
//  Collection.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

/// Collection construct used for collection/serie metadata
public class Collection {
    /// The name of the colection.
    public var name: String
    ///
    public var sortAs: String?
    /// An unambiguous reference to this contributor.
    public var identifier: String?
    /// Indicate the position of the book in the collection.
    public var position: Double?
    /// Elements of the collection.
    public var links = [Link]()
    
    public init(name: String) {
        self.name = name
    }
}
