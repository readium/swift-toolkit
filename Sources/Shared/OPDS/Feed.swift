//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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
        metadata = OpdsMetadata(title: title)
    }

    /// Return a String representing the URL of the searchLink of the feed.
    ///
    /// - Returns: The HREF value of the search link
    internal func getSearchLinkHref() -> String? {
        links.firstWithRel(.search)?.href
    }
}
