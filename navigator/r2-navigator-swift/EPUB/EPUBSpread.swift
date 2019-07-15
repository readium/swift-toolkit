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


enum EPUBSpread {
    case one(Link)
    case two(left: Link, right: Link)
    
    /// Returns the links in the spread, from left to right.
    var links: [Link] {
        switch self {
        case .one(let link):
            return [link]
        case .two(let left, let right):
            return [left, right]
        }
    }
    
    /// Returns the left-most link in the spread.
    var left: Link {
        return links.first!
    }
    
    /// Returns the right-most link in the spread.
    var right: Link {
        return links.last!
    }
    
    /// Returns whether the spread contains a resource with the given href.
    func containsHref(_ href: String) -> Bool {
        return links.first(withHref: href) != nil
    }
    
}

extension Array where Element == EPUBSpread {
    
    /// Builds a list of spreads for the given Publication.
    init(publication: Publication) {
        self.init()
        
//        for link in publication.readingOrder {
//            append(.one(link))
//        }
//        return
        
        let links = publication.readingOrder
        for i in stride(from: 0, to: links.count - 1, by: 2) {
            if links.indices.contains(i+1) {
                append(.two(left: links[i], right: links[i+1]))
            } else {
                append(.one(links[i]))
            }
        }
    }
    
    func firstIndex(withHref href: String) -> Int? {
        return firstIndex { spread in
            spread.links.contains { $0.href == href }
        }
    }
    
}
