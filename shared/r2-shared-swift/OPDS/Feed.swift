//
//  Feed.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//


/// Main structure of an OPDS catalog.
public class Feed {
    public var metadata: OpdsMetadata
    public var links: [Link]?
    public var facets: [Facet]?
    public var groups: [Group]?
    public var publications: [Publication]?
    public var navigation: [Link]?

    public init(title: String) {
        self.metadata = OpdsMetadata(title: title)
    }
}
