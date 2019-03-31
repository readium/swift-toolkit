//
//  Locator.swift
//  r2-shared-swift
//
//  Created by Aferdita Muriqi on 2/13/19.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//


import Foundation

public class Locator {
    public var href: String
    public var type: String
    public var title: String?
    public var locations: Locations?
    public var text: LocatorText?
    
    public init(href: String, type: String, title: String?, locations: Locations?, text: LocatorText?) {
        self.href = href
        self.type = type
        self.title = title
        self.locations = locations
        self.text = text
    }
    
}

public struct LocatorText:Codable {
    public var after: String?
    public var before: String?
    public var hightlight: String?
    public init(after: String? = nil, before: String? = nil, hightlight: String? = nil) {
        self.after = after
        self.before = before
        self.hightlight = hightlight
    }
    
    public init(fromString: String) {
        do {
            let decodedSentences = try JSONDecoder().decode(LocatorText.self, from: fromString.data(using: .utf8)!)
            self.after = decodedSentences.after
            self.before = decodedSentences.before
            self.hightlight = decodedSentences.hightlight
        } catch { print(error) }
    }
    
    public func toString() -> String? {
        do {
            let jsonData = try JSONEncoder().encode(self)
            return String(data: jsonData, encoding: .utf8)!
        } catch { print(error) }
        return nil
    }
    
}

/// Location : Class that contain the different variables needed to localize a particular position
public struct Locations:Codable {
    /// Contains one or more fragment in the resource referenced by the Locator Object.
    public var fragment: String?      // 1 = fragment identifier (toc, page lists, landmarks)
    /// Progression in the resource expressed as a percentage.
    public var progression: Double?    // 2 = bookmarks
    /// An index in the publication.
    public var position: Int?      // 3 = goto page
    
    public init(fragment: String? = nil, progression: Double? = nil, position: Int? = nil) {
        self.fragment = fragment
        self.progression = progression
        self.position = position
    }
    
    public init(fromString: String) {
        do {
            let decodedSentences = try JSONDecoder().decode(Locations.self, from: fromString.data(using: .utf8)!)
            self.fragment = decodedSentences.fragment
            self.progression = decodedSentences.progression
            self.position = decodedSentences.position
        } catch { print(error) }
    }
    
    public func toString() -> String? {
        do {
            let jsonData = try JSONEncoder().encode(self)
            return String(data: jsonData, encoding: .utf8)!
        } catch { print(error) }
        return nil
    }
}

public class Bookmark: Locator {
    public var bookID: Int
    public var publicationID: String
    public var resourceIndex: Int
    public var resourceHref: String
    public var resourceType: String
    public var resourceTitle: String
    public var location: Locations
    public var locatorText: LocatorText
    public var id: Int64?
    public var creationDate: Date;
    
    public init( bookID: Int,
                 publicationID: String,
                 resourceIndex: Int,
                 resourceHref: String,
                 resourceType: String,
                 resourceTitle: String,
                 location: Locations,
                 locatorText: LocatorText,
                 creationDate: Date = Date(),
                 id: Int64? = nil) {
        self.bookID = bookID
        self.publicationID = publicationID
        self.resourceIndex = resourceIndex
        self.resourceHref = resourceHref
        self.resourceType = resourceType
        self.resourceTitle = resourceTitle
        self.location = location
        self.locatorText = locatorText
        self.id = id
        self.creationDate = creationDate
        super.init(href: resourceHref, type: resourceType, title: resourceTitle, locations: location, text: locatorText)
    }
}
