//
//  EPUBSpread.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 15.07.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


struct EPUBSpread {
    
    /// Pages in the spread, in reading order.
    let pages: [Link]
    
    /// Spread reading progression direction.
    let readingProgression: ReadingProgression
    
    /// Rendition layout of the pages in the spread.
    let layout: EPUBRendition.Layout

    init(pages: [Link], readingProgression: ReadingProgression, layout: EPUBRendition.Layout) {
        precondition(!pages.isEmpty, "A spread must have at least one page")
        self.pages = pages
        self.readingProgression = readingProgression
        self.layout = layout
    }
    
    /// Pages in the spread, from left to right.
    var pagesLTR: [Link] {
        switch readingProgression {
        case .rtl:
            return pages.reversed()
        case .ltr, .auto:
            return pages
        }
    }
    
    /// Returns the left-most page in the spread.
    var left: Link {
        return pagesLTR.first!
    }
    
    /// Returns the right-most page in the spread.
    var right: Link {
        return pagesLTR.last!
    }
    
    /// Returns the leading page in the reading progression.
    var leading: Link {
        return pages.first!
    }
    
    /// Returns the trailing page in the reading progression.
    var trailing: Link {
        return pages.last!
    }
    
    /// Returns whether the spread contains a resource with the given href.
    func contains(href: String) -> Bool {
        return pages.first(withHref: href) != nil
    }
    
}

extension Array where Element == EPUBSpread {
    
    /// Builds a list of spreads for the given Publication.
    init(publication: Publication, readingProgression: ReadingProgression) {
        self.init()
        
        for link in publication.readingOrder {
            // FIXME: Use `EPUBRendition.layout(of link: Link)` once the positionList PR is merged
            let layout = link.properties.layout ?? publication.metadata.rendition?.layout ?? .reflowable
            append(EPUBSpread(pages: [link], readingProgression: readingProgression, layout: layout))
        }
        return
        
        let links = publication.readingOrder
        for i in stride(from: 0, to: links.count - 1, by: 2) {
            var pages: [Link] = []
            if links.indices.contains(i+1) {
                pages = [links[i], links[i+1]]
            } else {
                pages = [links[i]]
            }
            // FIXME: Use `EPUBRendition.layout(of link: Link)` once the positionList PR is merged
            let layout = pages[0].properties.layout ?? publication.metadata.rendition?.layout ?? .reflowable
            append(EPUBSpread(pages: pages, readingProgression: readingProgression, layout: layout))
        }
    }
    
    func firstIndex(withHref href: String) -> Int? {
        return firstIndex { spread in
            spread.pages.contains { $0.href == href }
        }
    }
    
}
