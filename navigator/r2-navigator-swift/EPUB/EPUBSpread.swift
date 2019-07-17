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
    
    enum PageCount: String {
        case one, two
    }
    
    /// Number of page "slots" in the spread.
    let pageCount: PageCount

    /// Links for the resources displayed in the spread, in reading order.
    /// Note: it's possible to have less links than the amount of `pageCount` available, because a single page might be displayed in a two-page spread (eg. with Properties.Page center, left or right)
    let links: [Link]
    
    /// Spread reading progression direction.
    let readingProgression: ReadingProgression
    
    /// Rendition layout of the links in the spread.
    let layout: EPUBRendition.Layout

    init(pageCount: PageCount, links: [Link], readingProgression: ReadingProgression, layout: EPUBRendition.Layout) {
        precondition(!links.isEmpty, "A spread must have at least one page")
        precondition(pageCount != .one || links.count == 1, "A one-page spread must have only one page")
        precondition(pageCount != .two || 1...2 ~= links.count, "A two-pages spread must have one or two pages max")
        self.pageCount = pageCount
        self.links = links
        self.readingProgression = readingProgression
        self.layout = layout
    }
    
    /// Links for the resources in the spread, from left to right.
    var linksLTR: [Link] {
        switch readingProgression {
        case .rtl:
            return links.reversed()
        case .ltr, .auto:
            return links
        }
    }
    
    /// Returns the left-most resource link in the spread.
    var left: Link {
        return linksLTR.first!
    }
    
    /// Returns the right-most resource link in the spread.
    var right: Link {
        return linksLTR.last!
    }
    
    /// Returns the leading resource link in the reading progression.
    var leading: Link {
        return links.first!
    }
    
    /// Returns the trailing resource link in the reading progression.
    var trailing: Link {
        return links.last!
    }
    
    /// Returns whether the spread contains a resource with the given href.
    func contains(href: String) -> Bool {
        return links.first(withHref: href) != nil
    }

    /// Returns the number of pages in a spread for the given parameters.
    ///
    /// - Parameters:
    ///   - publication: The publication to paginate.
    ///   - userSettings: The host app user settings, to determine the user preference regarding spreads.
    ///   - isLandscape: Whether the navigator viewport is in landscape or portrait.
    static func pageCountPerSpread(for publication: Publication, userSettings: UserSettings, isLandscape: Bool) -> PageCount {
        var setting = spreadSetting(in: userSettings)
        if setting == .auto, let publicationSetting = publication.metadata.rendition?.spread {
            setting = publicationSetting
        }
        
        switch setting {
        case .none:
            return .one
        case .both:
            return .two
        // FIXME: We consider that .auto means a 2p spread in landscape, and 1p in portrait. But this default should probably be customizable by the host app.
        case .auto, .landscape:
            return isLandscape ? .two : .one
        }
    }
    
    /// Returns the EPUBRendition spread setting for the given UserSettings.
    private static func spreadSetting(in userSettings: UserSettings) -> EPUBRendition.Spread {
        guard let columnCount = userSettings.userProperties.getProperty(reference: ReadiumCSSReference.columnCount.rawValue) as? Enumerable else {
            return .auto
        }
        switch columnCount.index {
        case 0:
            return .auto
        case 1:
            return .none
        default:
            return .both
        }
    }
    
}

extension Array where Element == EPUBSpread {
    
    /// Builds a list of spreads for the given Publication.
    ///
    /// - Parameters:
    ///   - publication: The Publication to build the spreads for.
    ///   - readingProgression: Reading progression direction used to layout the pages.
    ///   - pageCountPerSpread: Number of pages to display in a given spread (1 or 2).
    init(publication: Publication, readingProgression: ReadingProgression, pageCountPerSpread: EPUBSpread.PageCount) {
        self.init()
        
        func layoutOf(_ link: Link) -> EPUBRendition.Layout {
            // FIXME: Use `EPUBRendition.layout(of link: Link)` once the feature/positionList PR is merged
            return link.properties.layout ?? publication.metadata.rendition?.layout ?? .reflowable
        }

        switch pageCountPerSpread {
        case .one:
            for link in publication.readingOrder {
                append(EPUBSpread(pageCount: pageCountPerSpread, links: [link], readingProgression: readingProgression, layout: layoutOf(link)))
            }

        case .two:
            /// Builds two-page spreads from a list of links and a spread accumulator.
            func makeSpreads(for links: [Link], in spreads: [EPUBSpread] = []) -> [EPUBSpread] {
                var links = links
                var spreads = spreads
                guard !links.isEmpty else {
                    return spreads
                }
                
                let first = links.removeFirst()
                let layout = layoutOf(first)
                // To be a valid 2-pages spread, the pages must have the same rendition layout, and have consecutive position hints (Properties.Page).
                if let second = links.first, layout == layoutOf(second), areConsecutive(first, second) {
                    spreads.append(EPUBSpread(pageCount: pageCountPerSpread, links: [first, second], readingProgression: readingProgression, layout: layout))
                    links.removeFirst()
                } else {
                    spreads.append(EPUBSpread(pageCount: pageCountPerSpread, links: [first], readingProgression: readingProgression, layout: layout))
                }
                
                return makeSpreads(for: links, in: spreads)
            }
            
            /// Two resources are consecutive if their position hint (Properties.Page) are paired according to the reading progression.
            func areConsecutive(_ first: Link, _ second: Link) -> Bool {
                // Here we use the default publication reading progression instead of the custom one provided, otherwise the page position hints might be wrong, and we could end up with only one-page spreads.
                switch publication.contentLayout.readingProgression {
                case .ltr, .auto:
                    let firstPosition = first.properties.page ?? .left
                    let secondPosition = second.properties.page ?? .right
                    return (firstPosition == .left && secondPosition == .right)
                case .rtl:
                    let firstPosition = first.properties.page ?? .right
                    let secondPosition = second.properties.page ?? .left
                    return (firstPosition == .right && secondPosition == .left)
                }
            }
            
            append(contentsOf: makeSpreads(for: publication.readingOrder))
        }
    }
    
    func firstIndex(withHref href: String) -> Int? {
        return firstIndex { spread in
            spread.links.contains { $0.href == href }
        }
    }

}
