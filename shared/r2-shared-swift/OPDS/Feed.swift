//
//  Feed.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//


/// Main structure of an OPDS catalog.
public class Feed {
    public var metadata: OpdsMetadata
    public var links = [Link]()
    public var facets = [Facet]()
    public var groups = [Group]()
    public var publications = [Publication]()
    public var navigation = [Link]()
    public var context = [String]()

    public init(title: String) {
        self.metadata = OpdsMetadata(title: title)
    }

    /// Return a String representing the URL of the searchLink of the feed.
    ///
    /// - Returns: The HREF value of the search link
    internal func getSearchLinkHref() -> String? {
        return links.first(withRel: "search")?.href
    }
}
