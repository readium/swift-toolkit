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


/// A list of EPUB resources to be displayed together on the screen, as one-page or two-pages spread.
struct EPUBSpread: Loggable {
    
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
    let layout: EPUBLayout

    init(pageCount: PageCount, links: [Link], readingProgression: ReadingProgression, layout: EPUBLayout) {
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
        case .ltr, .ttb, .auto:
            return links
        case .rtl, .btt:
            return links.reversed()
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

    /// Returns whether the spread contains a resource with the given href.
    func contains(href: String) -> Bool {
        return links.first(withHREF: href) != nil
    }
    
    /// Returns a JSON representation of the links in the spread.
    /// The JSON is an array of link objects in reading progression order.
    /// Each link object contains:
    ///   - href: Href of the linked resource in the Publication
    ///   - url: Full URL to the resource.
    ///   - page [left|center|right]: (optional) Page position of the linked resource in the spread.
    func json(for publication: Publication) -> [[String: String]] {
        func makeLinkJSON(_ link: Link, page: Presentation.Page? = nil) -> [String: String]? {
            guard let url = link.url(relativeTo: publication.baseURL) else {
                log(.error, "Can't get URL for link \(link.href)")
                return nil
            }
            let page = page ?? link.properties.page ?? readingProgression.leadingPage
            return [
                "href": link.href,
                "url": url.absoluteString,
                "page": page.rawValue
            ]
        }
        
        var json: [[String: String]?] = []
        
        if links.count == 1 {
            json.append(makeLinkJSON(leading))
        } else {
            json.append(makeLinkJSON(left, page: .left))
            json.append(makeLinkJSON(right, page: .right))
        }

        return json.compactMap { $0 }
    }
    
    func jsonString(for publication: Publication) -> String {
        return serializeJSONString(json(for: publication)) ?? "[]"
    }


    /// Returns the number of pages in a spread for the given parameters.
    ///
    /// - Parameters:
    ///   - publication: The publication to paginate.
    ///   - userSettings: The host app user settings, to determine the user preference regarding spreads.
    ///   - isLandscape: Whether the navigator viewport is in landscape or portrait.
    static func pageCountPerSpread(for publication: Publication, userSettings: UserSettings, isLandscape: Bool) -> PageCount {
        var setting = spreadSetting(in: userSettings)
        if setting == .auto, let publicationSetting = publication.metadata.presentation.spread {
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
    private static func spreadSetting(in userSettings: UserSettings) -> Presentation.Spread {
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
    
    
    /// Builds a list of spreads for the given Publication.
    ///
    /// - Parameters:
    ///   - publication: The Publication to build the spreads for.
    ///   - readingProgression: Reading progression direction used to layout the pages.
    ///   - pageCountPerSpread: Number of pages to display in a given spread (1 or 2).
    static func makeSpreads(for publication: Publication, readingProgression: ReadingProgression, pageCountPerSpread: EPUBSpread.PageCount) -> [EPUBSpread] {
        switch pageCountPerSpread {
        case .one:
            return makeOnePageSpreads(for: publication, readingProgression: readingProgression)
        case .two:
            return makeTwoPagesSpreads(for: publication, readingProgression: readingProgression)
        }
    }

    /// Builds a list of one-page spreads for the given Publication.
    private static func makeOnePageSpreads(for publication: Publication, readingProgression: ReadingProgression) -> [EPUBSpread] {
        return publication.readingOrder.map {
            EPUBSpread(
                pageCount: .one,
                links: [$0],
                readingProgression: readingProgression,
                layout: publication.metadata.presentation.layout(of: $0)
            )
        }
    }
    
    /// Builds a list of two-page spreads for the given Publication.
    private static func makeTwoPagesSpreads(for publication: Publication, readingProgression: ReadingProgression) -> [EPUBSpread] {
        
        /// Builds two-pages spreads from a list of links and a spread accumulator.
        func makeSpreads(for links: [Link], in spreads: [EPUBSpread] = []) -> [EPUBSpread] {
            var links = links
            var spreads = spreads
            guard !links.isEmpty else {
                return spreads
            }
            
            let first = links.removeFirst()
            let layout = publication.metadata.presentation.layout(of: first)
            // To be displayed together, the two pages must have a fixed layout, and have consecutive position hints (Properties.Page).
            if let second = links.first,
                layout == .fixed,
                layout == publication.metadata.presentation.layout(of: second),
                areConsecutive(first, second)
            {
                spreads.append(EPUBSpread(
                    pageCount: .two, links: [first, second],
                    readingProgression: readingProgression, layout: layout)
                )
                links.removeFirst()  // Removes the consumed "second" page
            } else {
                spreads.append(EPUBSpread(
                    pageCount: .two, links: [first],
                    readingProgression: readingProgression, layout: layout)
                )
            }
            
            return makeSpreads(for: links, in: spreads)
        }
        
        /// Two resources are consecutive if their position hint (Properties.Page) are paired according to the reading progression.
        func areConsecutive(_ first: Link, _ second: Link) -> Bool {
            // Here we use the default publication reading progression instead of the custom one provided, otherwise the page position hints might be wrong, and we could end up with only one-page spreads.
            switch publication.metadata.effectiveReadingProgression {
            case .ltr, .ttb, .auto:
                let firstPosition = first.properties.page ?? .left
                let secondPosition = second.properties.page ?? .right
                return (firstPosition == .left && secondPosition == .right)
            case .rtl, .btt:
                let firstPosition = first.properties.page ?? .right
                let secondPosition = second.properties.page ?? .left
                return (firstPosition == .right && secondPosition == .left)
            }
        }
        
        return makeSpreads(for: publication.readingOrder)
    }

}

extension Array where Element == EPUBSpread {

    /// Returns the index of the first spread containing a resource with the given `href`.
    func firstIndex(withHref href: String) -> Int? {
        return firstIndex { spread in
            spread.links.contains { $0.href == href }
        }
    }

}
