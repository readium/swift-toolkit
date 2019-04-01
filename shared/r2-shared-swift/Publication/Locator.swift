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

/// https://github.com/readium/architecture/tree/master/locators
public class Locator: JSONEquatable, CustomStringConvertible, Loggable {
    
    /// The URI of the resource that the Locator Object points to.
    public var href: String  // URI
    
    /// The media type of the resource that the Locator Object points to.
    public var type: String
    
    /// The title of the chapter or section which is more relevant in the context of this locator.
    public var title: String?
    
    /// One or more alternative expressions of the location.
    public var locations: Locations?
    
    /// Textual context of the locator.
    public var text: LocatorText?
    
    public init(href: String, type: String, title: String? = nil, locations: Locations? = nil, text: LocatorText? = nil) {
        self.href = href
        self.type = type
        self.title = title
        self.locations = locations
        self.text = text
    }
    
    public init?(json: Any?) throws {
        if json == nil {
            return nil
        }
        guard let json = json as? [String: Any],
            let href = json["href"] as? String,
            let type = json["type"] as? String else
        {
            throw JSONError.parsing(Locator.self)
        }
        
        self.href = href
        self.type = type
        self.title = json["title"] as? String
        if let locations = json["locations"] {
            self.locations = try Locations(json: locations)
        }
        if let text = json["text"] {
            self.text = try LocatorText(json: text)
        }
    }
    
    public convenience init?(jsonString: String) throws {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!)
        } catch {
            Locator.log(.error, error)
            throw JSONError.parsing(Locator.self)
        }
        
        try self.init(json: json)
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "href": href,
            "type": type,
            "title": encodeIfNotNil(title),
            "locations": encodeIfNotEmpty(locations?.json),
            "text": encodeIfNotEmpty(text?.json)
        ])
    }
    
    public var jsonString: String? {
        return serializeJSONString(json)
    }
    
    public var description: String {
        return jsonString ?? "{}"
    }
    
}

public struct LocatorText: Equatable, Loggable {
    public var after: String?
    public var before: String?
    public var highlight: String?
    
    public init(after: String? = nil, before: String? = nil, highlight: String? = nil) {
        self.after = after
        self.before = before
        self.highlight = highlight
    }
    
    public init(json: Any) throws {
        guard let json = json as? [String: Any] else {
            throw JSONError.parsing(LocatorText.self)
        }
        self.after = json["after"] as? String
        self.before = json["before"] as? String
        self.highlight = json["highlight"] as? String
    }
    
    public init(fromString: String) {
        do {
            let json = try JSONSerialization.jsonObject(with: fromString.data(using: .utf8)!)
            try self.init(json: json)
        } catch {
            self.init()
            log(.error, error)
        }
    }

    public var json: [String: Any]? {
        return makeJSON([
            "after": encodeIfNotNil(after),
            "before": encodeIfNotNil(before),
            "highlight": encodeIfNotNil(highlight)
        ])
    }
    
    public func toString() -> String? {
        guard let json = self.json else {
            return nil
        }
        return serializeJSONString(json)
    }
    
}

/// Location : Class that contain the different variables needed to localize a particular position
public struct Locations: Equatable, Loggable {
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
    
    public init(json: Any) throws {
        guard let json = json as? [String: Any] else {
            throw JSONError.parsing(Locations.self)
        }
        self.fragment = json["fragment"] as? String
        self.progression = json["progression"] as? Double
        self.position = json["position"] as? Int
    }
    
    public init(fromString: String) {
        do {
            let json = try JSONSerialization.jsonObject(with: fromString.data(using: .utf8)!)
            try self.init(json: json)
        } catch {
            self.init()
            log(.error, error)
        }
    }
    
    public var json: [String: Any]? {
        return makeJSON([
            "fragment": encodeIfNotNil(fragment),
            "progression": encodeIfNotNil(progression),
            "position": encodeIfNotNil(position)
        ])
    }
    
    public func toString() -> String? {
        guard let json = self.json else {
            return nil
        }
        return serializeJSONString(json)
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
