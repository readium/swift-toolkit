//
//  WPLink.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Link Object for the Readium Web Publication Manifest.
/// https://readium.org/webpub-manifest/schema/link.schema.json
public struct WPLink: Equatable {
    
    /// URI or URI template of the linked resource.
    /// Note: a String because templates are lost with URL.
    public var href: String  // URI
    
    /// MIME type of the linked resource.
    public var type: String?
    
    /// Indicates that a URI template is used in href.
    public var templated: Bool
    
    /// Title of the linked resource.
    public var title: String?
    
    /// Relation between the linked resource and its containing collection.
    public var rels: [String]
    
    /// Properties associated to the linked resource.
    public var properties: WPProperties
    
    /// Height of the linked resource in pixels.
    public var height: Int?
    
    /// Width of the linked resource in pixels.
    public var width: Int?
    
    /// Bitrate of the linked resource in kbps.
    public var bitrate: Double?
    
    /// Length of the linked resource in seconds.
    public var duration: Double?
    
    /// Resources that are children of the linked resource, in the context of a given collection role.
    public var children: [WPLink]
    
    init(href: String, type: String? = nil, templated: Bool = false, title: String? = nil, rels: [String] = [], properties: WPProperties = WPProperties(), height: Int? = nil, width: Int? = nil, bitrate: Double? = nil, duration: Double? = nil, children: [WPLink] = []) {
        self.href = href
        self.type = type
        self.templated = templated
        self.title = title
        self.rels = rels
        self.properties = properties
        self.height = height
        self.width = width
        self.bitrate = bitrate
        self.duration = duration
        self.children = children
    }
    
    init(json: Any) throws {
        guard let json = json as? [String: Any],
            let href = json["href"] as? String else
        {
            throw WPParsingError.link
        }
        self.href = href
        self.type = json["type"] as? String
        self.templated = (json["templated"] as? Bool) ?? false
        self.title = json["title"] as? String
        self.rels = parseArray(json["rel"], allowingSingle: true)
        self.properties = try WPProperties(json: json["properties"]) ?? WPProperties()
        self.height = parsePositive(json["height"])
        self.width = parsePositive(json["width"])
        self.bitrate = parsePositiveDouble(json["bitrate"])
        self.duration = parsePositiveDouble(json["duration"])
        self.children = try [WPLink](json: json["children"])
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "href": href,
            "type": encodeIfNotNil(type),
            "templated": templated,
            "title": encodeIfNotNil(title),
            "rel": encodeIfNotEmpty(rels),
            "properties": encodeIfNotNil(properties.json),
            "height": encodeIfNotNil(height),
            "width": encodeIfNotNil(width),
            "bitrate": encodeIfNotNil(bitrate),
            "duration": encodeIfNotNil(duration),
            "children": encodeIfNotEmpty(children.json)
        ])
    }
    
}

/// Syntactic sugar to parse multiple JSON links into an array of WPLink.
/// eg. let links = [WPLink](json: [["href", "http://link1"], ["href", "http://link2"]])
extension Array where Element == WPLink {
    
    public init(json: Any?) throws {
        self.init()
        if json == nil {
            return
        }
        
        guard let json = json as? [Any] else {
            throw WPParsingError.link
        }
        let links = try json.map { try WPLink(json: $0) }
        append(contentsOf: links)
    }
    
    public var json: [[String: Any]] {
        return map { $0.json }
    }
    
}
